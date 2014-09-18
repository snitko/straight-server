module StraightServer
 
  class Order < Sequel::Model 

    prepend Straight::OrderModule

    def gateway
      @gateway ||= Gateway.find_by_id(gateway_id)
    end

  end

end
