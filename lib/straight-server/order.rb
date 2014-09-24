module StraightServer
 
  class Order < Sequel::Model 

    prepend Straight::OrderModule
    plugin :validation_helpers
    plugin :timestamps, create: :created_at, update: :updated_at

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

    def validate
      super # calling Sequel::Model validator
      errors.add(:amount,     "is invalid") if !amount.kind_of?(Numeric)     || amount <= 0
      errors.add(:gateway_id, "is invalid") if !gateway_id.kind_of?(Numeric) || gateway_id <= 0
      validates_unique   :id, :address, [:keychain_id, :gateway_id]
      validates_presence [:address, :keychain_id, :gateway_id, :amount]
    end

    def to_http_params
      "order_id=#{id}&amount=#{amount}&status=#{status}&address=#{address}&tid=#{tid}"
    end

    def start_periodic_status_check
      StraightServer.logger.info "Starting periodic status checks of the order #{self.id}"
    end

    def check_status_on_schedule(period: 10, iteration_index: 0)
      StraightServer.logger.info "Checking status of order #{self.id}"
    end

  end

end
