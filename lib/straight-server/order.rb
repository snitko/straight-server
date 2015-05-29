module StraightServer

  class Order < Sequel::Model

    include Straight::OrderModule
    plugin :validation_helpers
    plugin :timestamps, create: :created_at, update: :updated_at

    plugin :serialization

    # Additional data that can be passed and stored with each order. Not returned with the callback.
    serialize_attributes :marshal, :data

    # data that was provided by the merchan upon order creation and is sent back with the callback
    serialize_attributes :marshal, :callback_data

    # stores the response of the server to which the callback is issued
    serialize_attributes :marshal, :callback_response

    plugin :after_initialize
    def after_initialize
      @status = self[:status] || 0
    end

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
    # set StraightServer::Config.check_order_status_in_db_first to true
    def status(as_sym: false, reload: false)
      if reload && StraightServer::Config.check_order_status_in_db_first
        @old_status = self.status
        self.refresh
        unless self[:status] == @old_status
          @status         = self[:status]
          @status_changed = true
          self.gateway.order_status_changed(self)
        end
      end
      self[:status] = @status
    end

    def cancelable?
      status == Straight::Order::STATUSES.fetch(:new)
    end

    def cancel
      self.status = Straight::Order::STATUSES.fetch(:canceled)
      save
      StraightServer::Thread.interrupt(label: payment_id)
    end

    def save
      super # calling Sequel::Model save
      @status_changed = false
    end

    def to_h
      super.merge({ id: id, payment_id: payment_id, amount_in_btc: amount_in_btc(as: :string), keychain_id: keychain_id, last_keychain_id: self.gateway.last_keychain_id })
    end

    def to_json
      to_h.to_json
    end

    def validate
      super # calling Sequel::Model validator
      errors.add(:amount,     "is not numeric") if !amount.kind_of?(Numeric)
      errors.add(:amount,     "should be more than 0") if amount && amount <= 0
      errors.add(:gateway_id, "is invalid") if !gateway_id.kind_of?(Numeric) || gateway_id <= 0
      errors.add(:description, "should be shorter than 255 charachters") if description.kind_of?(String) && description.length > 255
      errors.add(:gateway, "is inactive, cannot create order for inactive gateway") unless gateway.active
      validates_unique   :id
      validates_presence [:address, :keychain_id, :gateway_id, :amount]
    end

    def to_http_params
      "order_id=#{id}&amount=#{amount}&amount_in_btc=#{amount_in_btc(as: :string)}&status=#{status}&address=#{address}&tid=#{tid}&keychain_id=#{keychain_id}&last_keychain_id=#{@gateway.last_keychain_id}"
    end

    def before_create
      self.payment_id = gateway.sign_with_secret("#{keychain_id}#{amount}#{created_at}#{(Order.max(:id) || 0)+1}")

      # Save info about current exchange rate at the time of purchase
      unless gateway.default_currency == 'BTC'
        self.data = {} unless self.data
        self.data[:exchange_rate] = { price: gateway.current_exchange_rate, currency: gateway.default_currency }
      end

      super
    end

    # Update Gateway's order_counters, incrementing the :new counter.
    # All other increments/decrements happen in the the Gateway#order_status_changed callback,
    # but the initial :new increment needs this code because the Gateway#order_status_changed
    # isn't called in this case.
    def after_create
      self.gateway.increment_order_counter!(:new) if StraightServer::Config.count_orders
    end

    # Reloads the method in Straight engine. We need to take
    # Order#created_at into account now, so that we don't start checking on
    # an order that is already expired. Or, if it's not expired yet,
    # we make sure to stop all checks as soon as it expires, but not later.
    def start_periodic_status_check(duration: nil)
      StraightServer.logger.info "Starting periodic status checks of order #{self.id} (expires in #{duration} seconds)"
      if (t = time_left_before_expiration) > 0
        check_status_on_schedule(duration: t)
      end
      self.save if self.status_changed?
    end

    def check_status_on_schedule(period: 10, iteration_index: 0, duration: 600, time_passed: 0)
      if StraightServer::Thread.interrupted?(thread: ::Thread.current)
        StraightServer.logger.info "Checking status of order #{self.id} interrupted"
        return
      end
      StraightServer.logger.info "Checking status of order #{self.id}"
      super
    end

    def time_left_before_expiration
      time_passed_after_creation = (Time.now - created_at).to_i
      gateway.orders_expiration_period+(StraightServer::Config.expiration_overtime || 0) - time_passed_after_creation
    end

  end

end
