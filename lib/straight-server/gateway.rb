require 'digest/md5'

module StraightServer

  # This module contains common features of Gateway, later to be included
  # in one of the classes below.
  module GatewayModule

    class InvalidSignature < Exception; end
    class InvalidOrderId   < Exception; end

    CALLBACK_URL_ATTEMPT_TIMEFRAME = 3600 # seconds

    def initialize(*attrs)
      
      # When the status of an order changes, we send an http request to the callback_url
      @order_callbacks = [ lambda { |order| send_callback_http_request(order) } ]

      super
    end
    
    # Creates a new order and saves into the DB. Checks if the MD5 hash
    # is correct first.
    def create_order(attrs={})
      StraightServer.logger.info "Creating new order with attrs: #{attrs}"
      signature = attrs.delete(:signature)
      raise InvalidOrderId if check_signature && (attrs[:id].nil? || attrs[:id].to_i <= 0)
      if !check_signature || md5(attrs[:id]) == signature
        order            = order_for_keychain_id(amount: attrs[:amount], keychain_id: increment_last_keychain_id!)
        order.id         = attrs[:id].to_i if attrs[:id]
        order.gateway    = self
        order.save
        self.save
        StraightServer.logger.info "Order #{order.id} created: #{order.to_h}"
        order
      else
        StraightServer.logger.warn "WARNING: invalid signature, cannot create an order for gateway (#{@gateway.id})"
        raise InvalidSignature
      end
    end

    # Used to track the current keychain_id number, which is used by
    # Straight::Gateway to generate addresses from the pubkey. The number is supposed
    # to be incremented by 1. In the case of a Config file type of Gateway, the value
    # is stored in a file in the .straight directory.
    def increment_last_keychain_id!
      self.last_keychain_id += 1
      self.save
      self.last_keychain_id
    end

    private

      def md5(order_id)
        Digest::MD5.hexdigest(order_id.to_s + secret)
      end

      # Tries to send a callback HTTP request to the resource specified
      # in the #callback_url. If it fails for any reason, it keeps trying for an hour (3600 seconds)
      # making 10 http requests, each delayed by twice the time the previous one was delayed.
      # This method is supposed to be running in a separate thread.
      def send_callback_http_request(order, delay: 5)
        return if callback_url.nil?
        uri = URI.parse("#{callback_url}?#{order.to_http_params}")
        begin
          http = uri.read(read_timeout: 4)
          raise CallbackUrlBadResponse unless http.status.first.to_i == 200
        rescue Exception => e
          if delay < CALLBACK_URL_ATTEMPT_TIMEFRAME
            sleep(delay)
            send_callback_http_request(order, delay: delay*2)
          end
        end
      end

  end

  # Uses database to load and save attributes
  class GatewayOnDB < Sequel::Model(:gateways)
    prepend Straight::GatewayModule
    include GatewayModule
    plugin :timestamps, create: :created_at, update: :updated_at
  end

  # Uses a config file to load attributes and a special _last_keychain_id file
  # to store last_keychain_id
  class GatewayOnConfig

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

    # If set to false, doesn't require an unique id of the order along with
    # the signed md5 hash of that id + secret to be passed into the #create_order method.
    attr_accessor :check_signature

    # A url to which the gateway will send an HTTP request with the status of the order data
    # (in JSON) when the status of the order is changed. The response should always be 200,
    # otherwise the gateway will awesome something went wrong and will keep trying to send requests
    # to this url according to a specific shedule.
    attr_accessor :callback_url

    # This will be assigned the number that is the order in which this gateway follows in
    # the config file.
    attr_accessor :id

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

    # This will later be used in the #find_by_id. Because we don't use a DB,
    # the id will actually be the index of an element in this Array. Thus,
    # the order in which gateways follow in the config file is important.
    @@gateways = []

    # Create instances of Gateway by reading attributes from Config
    i = 0
    StraightServer::Config.gateways.each do |name, attrs|
      i += 1
      gateway = self.new
      gateway.pubkey                 = attrs['pubkey']
      gateway.confirmations_required = attrs['confirmations_required'].to_i
      gateway.order_class            = attrs['order_class']
      gateway.secret                 = attrs['secret']
      gateway.check_signature        = attrs['check_signature']
      gateway.callback_url           = attrs['callback_url']
      gateway.name                   = name
      gateway.id                     = i
      gateway.load_last_keychain_id!
      @@gateways << gateway
    end
    

    # This method is a replacement for the Sequel's model one used in DB version of the gateway
    # and it finds gateways using the index of @@gateways Array.
    def self.find_by_id(id)
      @@gateways[id.to_i-1]
    end

  end

  # It may not be a perfect way to implement such a thing, but it gives enough flexibility to people
  # so they can simply start using a single gateway on their machines, a gateway which attributes are defined
  # in a config file instead of a DB. That way they don't need special tools to access the DB and create
  # a gateway, but can simply edit the config file.
  Gateway = if StraightServer::Config.gateways_source = 'config'
    GatewayOnConfig
  else
    GatewayOnDB
  end

end
