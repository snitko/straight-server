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

    def save
      super # calling Sequel::Model save
      @status_changed = false
    end

    def status_changed?
      @status_changed
    end

    def to_h
      super.merge({ id: id, payment_id: payment_id })
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

    def start_periodic_status_check
      StraightServer.logger.info "Starting periodic status checks of the order #{self.id}"
      super
    end

    def check_status_on_schedule(period: 10, iteration_index: 0)
      StraightServer.logger.info "Checking status of order #{self.id}"
      super
    end

    def before_create
      self.payment_id = gateway.sign_with_secret("#{id}#{amount}#{created_at}")
      super
    end

    # Reloads the method in Straight engine. We need to take
    # Order#created_at into account now, so that we don't start checking on
    # an order that is already expired. Or, if it's not expired yet,
    # we make sure to stop all checks as soon as it expires, but not later.
    def start_periodic_status_check(duration: @gateway.orders_expiration_period)
      if (t = time_left_before_expiration) > 0
        check_status_on_schedule(duration: t)
      end
    end

    def time_left_before_expiration(duration: @gateway.orders_expiration_period)
      time_passed_after_creation = (Time.now - created_at).to_i
      @gateway.orders_expiration_period-time_passed_after_creation
    end

  end

end
