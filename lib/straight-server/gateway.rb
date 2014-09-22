require 'digest/md5'

module StraightServer

  # This module contains commong features of Gateway, later to be included
  # in one o the classes below.
  module GatewayModule

    class InvalidSignature < Exception; end
    class InvalidOrderId   < Exception; end
    
    # Creates a new order and saves into the DB. Checks if the MD5 hash
    # is correct first.
    def create_order(attrs={})
      signature = attrs.delete(:signature)
      raise InvalidOrderId if check_signature && (attrs[:id].nil? || attrs[:id].to_i <= 0)
      if !check_signature || md5(attrs[:id]) == signature
        order_for_id(id: attrs[:id], amount: attrs[:amount], keychain_id: increment_last_keychain_id!)
        self.save
      else
        raise InvalidSignature
      end
    end

    def increment_last_keychain_id!
      self.last_keychain_id += 1
      self.save
      self.last_keychain_id
    end

    private

      def md5(order_id)
        Digest::MD5.hexdigest(order_id.to_s + secret)
      end

  end

  # Uses database to load and save attributes
  class GatewayOnDB < Sequel::Model(:gateways)
    prepend Straight::GatewayModule
    prepend GatewayModule
    plugin :timestamps, create: :created_at, update: :updated_at
  end

  # Uses a config file to load attributes and a special _last_keychain_id file
  # to store last_keychain_id
  class GatewayOnConfig

    prepend Straight::GatewayModule
    prepend GatewayModule

    # This is the key that allows users (those, who use the gateway,
    # online stores, for instance) to connect and create orders.
    # It is not used directly, but is mixed with all the params being sent
    # and a MD5 hash is calculted. Then the gateway checks whether the
    # MD5 hash is correct.
    attr_accessor :secret

    # This is used to generate the next address to accept payments
    attr_accessor :last_keychain_id

    # If set to false, doesn't require an unique id of the order along with
    # the signed md5 hash of that id + secret to be passed into the #create_order method.
    attr_accessor :check_signature

    # Because this is a config based gateway, we only save last_keychain_id
    # and nothing more.
    def save
      File.open(@last_keychain_id_file, 'w') {|f| f.write(last_keychain_id) }
    end

    # Loads last_keychain_id from a file in the .straight dir.
    # If the file doesn't exist, we create it. Later, whenever an attribute is updated,
    # we save it to the file.
    def load_last_keychain_id!
      @last_keychain_id_file = StraightServer::Initializer::STRAIGHT_CONFIG_PATH +
                               "/#{name}_last_keychain_id"
      if File.exists?(@last_keychain_id_file)
        self.last_keychain_id = File.read(@last_keychain_id_file).to_i
      else
        self.last_keychain_id = 0
        save
      end
    end

    @@gateways = []
    StraightServer::Config.gateways.each do |name, attrs|
      gateway = self.new
      gateway.pubkey                 = attrs['pubkey']
      gateway.confirmations_required = attrs['confirmations_required'].to_i
      gateway.order_class            = attrs['order_class']
      gateway.secret                 = attrs['secret']
      gateway.check_signature        = attrs['check_signature']
      gateway.name                   = name
      gateway.load_last_keychain_id!
      @@gateways << gateway
    end
    
    attr_accessor :id

    def self.find_by_id(id)
      @@gateways[id-1]
    end

  end

  Gateway = if StraightServer::Config.gateways_source = 'config'
    GatewayOnConfig
  else
    GatewayOnDB
  end

end
