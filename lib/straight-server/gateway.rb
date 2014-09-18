require 'digest/md5'

module StraightServer

  # This module contains commong features of Gateway, later to be included
  # in one o the classes below.
  module GatewayModule

    class InvalidSignature < Exception; end
    
    # Creates a new order and saves into the DB. Checks if the MD5 hash
    # is correct first.
    def create_order(attrs={})
      signature = attrs.delete(:signature)
      if md5(attrs) == signature
        order_for_id(amount: attrs[:amount], keychain_id: last_keychain_id+1)
      else
        raise InvalidSignature
      end
    end

    private

      def md5(params)
        Digest::MD5.hexdigest(params.values.map(&:to_s).join + secret)
      end

  end

  if StraightServer::Config.gateways_source = 'config'

    class Gateway

      prepend Straight::GatewayModule
      include GatewayModule

      # This is the key that allows users (those, who use the gateway,
      # online stores, for instance) to connect and create orders.
      # It is not used directly, but is mixed with all the params being sent
      # and a MD5 hash is calculted. Then the gateway checks whether the
      # MD5 hash is correct.
      attr_accessor :secret

      # This is used to generate the next address to accept payments
      attr_accessor :last_keychain_id
 
      @@gateways = []
      StraightServer::Config.gateways.each do |name, attrs|
        gateway = self.new
        gateway.pubkey                 = attrs['pubkey']
        gateway.confirmations_required = attrs['confirmations_required'].to_i
        gateway.order_class            = attrs['order_class']
        gateway.secret                 = attrs['secret']
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
      include GatewayModule
    end

  end

end
