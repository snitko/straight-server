module StraightServer
 
  class Order < Sequel::Model 

    prepend Straight::OrderModule
    plugin :validation_helpers
    plugin :timestamps, create: :created_at, update: :updated_at

    def gateway
      @gateway ||= Gateway.find_by_id(gateway_id)
    end

    def create(attrs={})
    end

    def validate
      super
      errors.add(:amount,     "is invalid") if !amount.kind_of?(Numeric)     || amount <= 0
      errors.add(:gateway_id, "is invalid") if !gateway_id.kind_of?(Numeric) || gateway_id <= 0
      validates_unique   :id, :address, [:keychain_id, :gateway_id]
      validates_presence [:id, :address, :keychain_id, :gateway_id, :amount]
    end

  end

end
