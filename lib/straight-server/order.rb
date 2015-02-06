module StraightServer
 
  class Order < Sequel::Model 

    include Straight::OrderModule
    plugin :validation_helpers
    plugin :timestamps, create: :created_at, update: :updated_at

    plugin :serialization
    serialize_attributes :marshal, :callback_response

    def gateway
      @gateway ||= Gateway.find_by_id(gateway_id)
    end
    
    def gateway=(g)
      self.gateway_id = g.id
      @gateway        = g
    end

    # This method is called from the Straight::OrderModule::Prependable
    # using super(). The reason it is reloaded here is because sometimes
    # we want to query the DB first and see if status has changed there.
    #
    # If it indeed changed in the DB and is > 1, then the original
    # Straight::OrderModule::Prependable#status method will not try to
    # query the blockchain (using adapters) because the status has already
    # been changed to be > 1.
    #
    # This is mainly useful for debugging. For example,
    # when testing payments, you don't actually want to pay, you can just
    # run the server console, change order status in the DB and see how your
    # client picks it up, showing you that your order has been paid for.
    #
    # If you want the feature described above on,
    # set Gateway#check_order_status_in_db_first to true
    def status(as_sym: false, reload: false)
      if reload && gateway.check_order_status_in_db_first
        old_status = self.status
        self.refresh
        unless self.status == old_status
          @status_changed = true 
          self.gateway.order_status_changed(self)
        end
      end
      self[:status]
    end

    def save
      super # calling Sequel::Model save
      @status_changed = false
    end

    def to_h
      super.merge({ id: id, payment_id: payment_id, amount_in_btc: amount_in_btc(as: :string) })
    end

    def to_json
      to_h.to_json
    end

    def validate
      super # calling Sequel::Model validator
      errors.add(:amount,     "is invalid") if !amount.kind_of?(Numeric)     || amount <= 0
      errors.add(:gateway_id, "is invalid") if !gateway_id.kind_of?(Numeric) || gateway_id <= 0
      errors.add(:description, "should be shorter than 255 charachters") if description.kind_of?(String) && description.length > 255
      validates_unique   :id, :address, [:keychain_id, :gateway_id]
      validates_presence [:address, :keychain_id, :gateway_id, :amount]
    end

    def to_http_params
      "order_id=#{id}&amount=#{amount}&status=#{status}&address=#{address}&tid=#{tid}"
    end

    def before_create
      self.payment_id = gateway.sign_with_secret("#{id}#{amount}#{created_at}")
      super
    end

    # Reloads the method in Straight engine. We need to take
    # Order#created_at into account now, so that we don't start checking on
    # an order that is already expired. Or, if it's not expired yet,
    # we make sure to stop all checks as soon as it expires, but not later.
    def start_periodic_status_check(duration: gateway.orders_expiration_period)
      StraightServer.logger.info "Starting periodic status checks of the order #{self.id}"
      if (t = time_left_before_expiration) > 0
        check_status_on_schedule(duration: t)
      end
      self.save if self.status_changed?
    end

    def check_status_on_schedule(period: 10, iteration_index: 0, duration: 600, time_passed: 0)
      StraightServer.logger.info "Checking status of order #{self.id}"
      super
    end

    def time_left_before_expiration(duration: gateway.orders_expiration_period)
      time_passed_after_creation = (Time.now - created_at).to_i
      @gateway.orders_expiration_period-time_passed_after_creation
    end

  end

end
