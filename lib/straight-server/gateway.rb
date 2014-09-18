module StraightServer

  if StraightServer::Config.gateways_source = 'config'

    class Gateway

      prepend Straight::GatewayModule
      
      @@gateways = [] # read the config file
      attr_accessor :id

      def self.find_by_id(id)
        @@gateways[id-1]
      end

    end

  else

    class Gateway < Sequel::Model
      prepend Straight::GatewayModule
    end

  end

end
