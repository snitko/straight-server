module StraightServer

  if StraightServer::Config.gateways_source = 'config'

    class Gateway

      prepend Straight::GatewayModule
      
      @@gateways = []
      StraightServer::Config.gateways.each do |name, attrs|
        gateway = self.new
        gateway.pubkey                 = attrs['pubkey']
        gateway.confirmations_required = attrs['confirmations_required'].to_i
        gateway.order_class            = attrs['order_class']
        gateway.name                   = name
        @@gateways << gateway
      end
      
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
