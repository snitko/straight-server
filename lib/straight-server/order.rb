module StraightServer
 
  class Order < Sequel::Model 

    prepend Straight::OrderModule

    def gateway
      Gateway.find_by_id(gateway_id)
    end

  end

end
