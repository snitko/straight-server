module StraightServer
 
  class Order < Sequel::Model 

    prepend Straight::Order

    def gateway
      Gateway.find_by_id(gateway_id)
    end

  end

end
