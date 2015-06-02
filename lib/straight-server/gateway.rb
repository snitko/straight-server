module StraightServer

  # This module contains common features of Gateway, later to be included
  # in one of the classes below.
  module GatewayModule

    # Temporary fix for straight server benchmarking
    @@redis = StraightServer::Config.redis[:connection] if StraightServer::Config.redis
    @@websockets = {}

    def fetch_transactions_for(address)
      try_adapters(@blockchain_adapters, type: 'blockchain') { |b| b.fetch_transactions_for(address) }
    end

    class InvalidSignature           < Exception; end
    class InvalidOrderId             < Exception; end
    class CallbackUrlBadResponse     < Exception; end
    class WebsocketExists            < Exception; end
    class WebsocketForCompletedOrder < Exception; end
    class GatewayInactive            < Exception; end
    class NoBlockchainAdapters       < Exception
      def message
        "No blockchain adapters were found! StraightServer cannot query the blockchain.\n" +
        "Check your ~/.straight/config.yml file and make sure valid blockchain adapters\n" +
        "are present."
      end
    end
    class NoWebsocketsForNewGateway  < Exception
      def message
        "You're trying to get access to websockets on a Gateway that hasn't been saved yet"
      end
    end
    class OrderCountersDisabled      < Exception
      def message
        "Please enable order counting in config file! You can do is using the following option:\n\n" +
        "  count_orders: true\n\n" +
        "and don't forget to provide Redis connection info by adding this to the config file as well:\n\n" +
        "  redis:\n" +
        "    host: localhost\n" +
        "    port: 6379\n" +
        "    db:   null\n"
      end
    end

    CALLBACK_URL_ATTEMPT_TIMEFRAME = 3600 # seconds


    ############# Initializers methods ########################################################
    # We have separate methods, because with GatewayOnDB they are called from #after_initialize
    # but in GatewayOnConfig they are called from #initialize intself.
    # #########################################################################################
    #
    def initialize_exchange_rate_adapters
      @exchange_rate_adapters ||= []
      if self.exchange_rate_adapter_names.kind_of?(Array) && self.exchange_rate_adapter_names
        self.exchange_rate_adapter_names.each do |adapter|
          begin
            @exchange_rate_adapters << Straight::ExchangeRate.const_get("#{adapter}Adapter").instance
          rescue NameError => e
            puts "WARNING: No exchange rate adapter with the name #{adapter} was found!"
          end
        end
      end
    end

    def initialize_blockchain_adapters
      @blockchain_adapters = []
      StraightServer::Config.blockchain_adapters.each do |a|

        adapter = begin
          Straight::Blockchain.const_get("#{a}Adapter")
        rescue NameError
          begin
            Kernel.const_get(a)
          rescue NameError
            puts "WARNING: No blockchain adapter with the name #{a} was found!"
            nil
          end
        end

        @blockchain_adapters << adapter.mainnet_adapter if adapter
      end
      raise NoBlockchainAdapters if @blockchain_adapters.empty?
    end

    def initialize_callbacks
      # When the status of an order changes, we send an http request to the callback_url
      # and also notify a websocket client (if present, of course).
      @order_callbacks = [
        lambda do |order|
          StraightServer::Thread.new do
            send_callback_http_request     order
            send_order_to_websocket_client order
          end
        end
      ]
    end

    def initialize_status_check_schedule
      @status_check_schedule = Straight::GatewayModule::DEFAULT_STATUS_CHECK_SCHEDULE
    end
    #
    ############# END OF Initializers methods ##################################################


    # Creates a new order and saves into the DB. Checks if the MD5 hash
    # is correct first.
    def create_order(attrs={})

      raise GatewayInactive unless self.active

      StraightServer.logger.info "Creating new order with attrs: #{attrs}"
      signature = attrs.delete(:signature)
      if !check_signature || sign_with_secret(attrs[:keychain_id]) == signature
        raise InvalidOrderId if check_signature && (attrs[:keychain_id].nil? || attrs[:keychain_id].to_i <= 0)

        # If we decide to reuse the order, we simply need to supply the
        # keychain_id that was used in the order we're reusing.
        # The address will be generated correctly.
        if reused_order = find_reusable_order
          attrs[:keychain_id] = reused_order.keychain_id
        end

        order = new_order(
          amount:           attrs[:amount],
          keychain_id:      attrs[:keychain_id] || self.last_keychain_id+1,
          currency:         attrs[:currency],
          btc_denomination: attrs[:btc_denomination]
        )
        order.id            = attrs[:id].to_i       if attrs[:id]
        order.data          = attrs[:data]          if attrs[:data]
        order.callback_data = attrs[:callback_data] if attrs[:callback_data]
        order.gateway       = self
        order.description   = attrs[:description]
        order.reused        = reused_order.reused + 1 if reused_order
        order.save

        self.update_last_keychain_id(attrs[:keychain_id]) unless order.reused > 0
        self.save
        StraightServer.logger.info "Order #{order.id} created: #{order.to_h}"
        order
      else
        StraightServer.logger.warn "Invalid signature, cannot create an order for gateway (#{id})"
        raise InvalidSignature
      end
    end

    def update_last_keychain_id(new_value=nil)
      #new_value = nil if new_value && new_value.empty?
      new_value ? self.last_keychain_id = new_value : self.last_keychain_id += 1
    end

    def add_websocket_for_order(ws, order)
      raise WebsocketExists            unless websockets[order.id].nil?
      raise WebsocketForCompletedOrder unless order.status < 2
      StraightServer.logger.info "Opening ws connection for #{order.id}"
      ws.on(:close) do |event|
        websockets.delete(order.id)
        StraightServer.logger.info "Closing ws connection for #{order.id}"
      end
      websockets[order.id] = ws
      ws
    end

    def websockets
      raise NoWebsocketsForNewGateway unless self.id
      @@websockets[self.id]
    end

    def send_order_to_websocket_client(order)
      if ws = websockets[order.id]
        ws.send(order.to_json)
        ws.close
      end
    end

    def sign_with_secret(content, level: 1)
      result = content.to_s
      level.times do
        result = OpenSSL::HMAC.digest('sha256', secret, result).unpack("H*").first
      end
      result
    end

    def order_status_changed(order)
      statuses = Order::STATUSES.invert
      if StraightServer::Config.count_orders
        increment_order_counter!(statuses[order.old_status], -1) if order.old_status
        increment_order_counter!(statuses[order.status])
      end
      super
    end

    def order_counters(reload: false)
      return @order_counters if @order_counters && !reload
      @order_counters = {
        new:         get_order_counter(:new),
        unconfirmed: get_order_counter(:unconfirmed),
        paid:        get_order_counter(:paid),
        underpaid:   get_order_counter(:underpaid),
        overpaid:    get_order_counter(:overpaid),
        expired:     get_order_counter(:expired),
        canceled:    get_order_counter(:canceled),
      }
    end

    def get_order_counter(counter_name)
      raise OrderCountersDisabled unless StraightServer::Config.count_orders
      @@redis.get("#{StraightServer::Config.redis[:prefix]}:gateway_#{id}:#{counter_name}_orders_counter").to_i || 0
    end

    def increment_order_counter!(counter_name, by=1)
      raise OrderCountersDisabled unless StraightServer::Config.count_orders
      @@redis.incrby("#{StraightServer::Config.redis[:prefix]}:gateway_#{id}:#{counter_name}_orders_counter", by)
    end

    # If we have more than Config.reuse_address_orders_threshold i a row for this gateway,
    # this method returns the one which keychain_id (and, consequently, address) is to be reused.
    # It also checks (just in case) if any transactions has been made to the addres-to-be-reused,
    # because even though the order itself might be expired, the address might have been used for
    # something else.
    #
    # If there were transactions to it, there's actually no need to reuse the address and we can
    # safely return nil.
    #
    # Also, see comments for #find_expired_orders_row method.
    def find_reusable_order
      expired_orders = find_expired_orders_row
      if expired_orders.size >= Config.reuse_address_orders_threshold &&
      fetch_transactions_for(expired_orders.last.address).empty?
        return expired_orders.last
      end
      nil
    end

    private

      # Tries to send a callback HTTP request to the resource specified
      # in the #callback_url. If it fails for any reason, it keeps trying for an hour (3600 seconds)
      # making 10 http requests, each delayed by twice the time the previous one was delayed.
      # This method is supposed to be running in a separate thread.
      def send_callback_http_request(order, delay: 5)
        return if callback_url.nil?

        StraightServer.logger.info "Attempting to send request to the callback url for order #{order.id} to #{callback_url}..."

        # Composing the request uri here
        signature = self.check_signature ? "&signature=#{sign_with_secret(order.id)}" : ''
        callback_data = order.callback_data ? "&callback_data=#{order.callback_data}" : ''
        uri           = URI.parse(callback_url + '?' + order.to_http_params + signature + callback_data)

        begin
          response = Net::HTTP.get_response(uri)
          order.callback_response = { code: response.code, body: response.body }
          order.save
          raise CallbackUrlBadResponse unless response.code.to_i == 200
        rescue Exception => e
          if delay < CALLBACK_URL_ATTEMPT_TIMEFRAME
            sleep(delay)
            send_callback_http_request(order, delay: delay*2)
          else
            StraightServer.logger.warn "Callback request for order #{order.id} failed, see order's #callback_response field for details"
          end
        end

        StraightServer.logger.info "Callback request for order #{order.id} performed successfully"
      end


      # Wallets that support BIP32 do a limited address lookup. If you have 20 empty addresses in a row
      # (actually not 20, but Config.reuse_address_orders_threshold, 20 is the default value) it won't
      # look past it and if an order is generated with the 21st address and Bitcoins are paid there,
      # the wallet may not detect it. Thus we need to always check for the number of expired orders
      # in a row and reuse an address.
      #
      # This method takes care of the first part of that equation: finds the row of expired orders.
      # It works like this:
      #
      # 1. Finds 20 last orders
      # 2. Checks if they form a row of expired orders, that is if there is no non-expired non-new orders
      # in the array:
      #
      #   if YES (all orders in the row are indeed expired)
      #     a) Try the next 20 until we find that one non-expired, non-new order
      #     b) Put all orders in an array, then slice it so only the oldest 20 are there
      #     c) return 20 oldest expired orders
      #
      #   if NO (some orders are paid)
      #     Return the row of expired orders - which is not enough to trigger a reuse
      #     (the triger is in the #find_reusable_order method, which calls this one).
      def find_expired_orders_row

        orders = []
        row    = nil
        offset = 0

        while row.nil? || row.size > 0
          row = Order.where(gateway_id: self.id).order(Sequel.desc(:keychain_id), Sequel.desc(:reused)).limit(Config.reuse_address_orders_threshold).offset(offset).to_a

          row.reject! do |o|
            reject = false
            row.each do |o2|
              reject = true if o.keychain_id == o2.keychain_id && o.reused < o2.reused
            end
            reject
          end

          row.sort! { |o1, o2| o2.id <=> o1.id }

          row.each do |o|
            if o.status == Order::STATUSES[:expired]
              orders.unshift(o)
            elsif o.status == Order::STATUSES[:new]
              next
            else
              return orders[0...Config.reuse_address_orders_threshold]
            end
          end
          offset += Config.reuse_address_orders_threshold
        end

        orders

      end

  end

  # Uses database to load and save attributes
  class GatewayOnDB < Sequel::Model(:gateways)

    include Straight::GatewayModule
    include GatewayModule
    plugin :timestamps, create: :created_at, update: :updated_at
    plugin :serialization, :marshal, :exchange_rate_adapter_names
    plugin :after_initialize

    def self.find_by_hashed_id(s)
      self.where(hashed_id: s).first
    end

    # This virtual attribute is important because it's difficult to detect whether secret was actually
    # updated or not. Sequel's #changed_columns may mistakenly say :secret attr was changed, while it
    # hasn't. Thus we provide a manual way of ensuring this. It's also better and works as safety switch:
    # we don't want somebody accidentally updating a secret.
    attr_accessor :update_secret

    def before_create
      super
      encrypt_secret
    end

    def before_update
      encrypt_secret if @update_secret
      @update_secret = false
      super
    end

    def after_create
      @@websockets[self.id] = {}
      update(hashed_id: OpenSSL::HMAC.digest('sha256', Config.server_secret, self.id.to_s).unpack("H*").first)
    end

    def after_initialize
      @status_check_schedule = Straight::GatewayModule::DEFAULT_STATUS_CHECK_SCHEDULE
      @@websockets[self.id] ||= {} if self.id
      initialize_callbacks
      initialize_exchange_rate_adapters
      initialize_blockchain_adapters
      initialize_status_check_schedule
    end

    # We cannot allow to store gateway secret in a DB plaintext, this would be completetly unsecure.
    # Althougth we use symmetrical encryption here and store the encryption key in the
    # server's in a special file (~/.straight/server_secret), which in turn can also be stolen,
    # this is still marginally better than doing nothing.
    #
    # Also, server admnistrators now have the freedom of developing their own strategy
    # of storing that secret - it doesn't have to be stored on the same machine.
    def secret
      decrypt_secret
    end

    def self.find_by_id(id)
      self[id]
    end

    def encrypt_secret
      cipher           = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.encrypt
      cipher.key       = OpenSSL::HMAC.digest('sha256', 'nonce', Config.server_secret).unpack("H*").first[0,16]

      cipher.iv        = iv = OpenSSL::HMAC.digest('sha256', 'nonce', "#{self.class.max(:id)}#{Config.server_secret}").unpack("H*").first[0,16]
      raise "cipher.iv cannot be nil" unless iv

      encrypted        = cipher.update(self[:secret]) << cipher.final()
      base64_encrypted = Base64.strict_encode64(encrypted).encode('utf-8')
      result           = "#{iv}:#{base64_encrypted}"

      # Check whether we can decrypt. It should not be possible to encrypt the
      # gateway secret unless we are sure we can decrypt it.
      if decrypt_secret(result) == self[:secret]
        self.secret = result
      else
        raise "Decrypted and original secrets don't match! Cannot proceed with writing the encrypted gateway secret."
      end
    end

    def address_provider
      Kernel.const_get("Straight::AddressProvider::#{self[:address_provider]}")
    end

    private

      def decrypt_secret(encrypted_field=self[:secret])
        decipher      = OpenSSL::Cipher::AES.new(128, :CBC)
        iv, encrypted = encrypted_field.split(':')
        decipher.decrypt
        decipher.key  = OpenSSL::HMAC.digest('sha256', 'nonce', Config.server_secret).unpack("H*").first[0,16]
        decipher.iv   = iv
        decipher.update(Base64.decode64(encrypted)) + decipher.final
      end

  end

  # Uses a config file to load attributes and a special _last_keychain_id file
  # to store last_keychain_id
  class GatewayOnConfig

    include Straight::GatewayModule
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

    attr_accessor :exchange_rate_adapter_names
    attr_accessor :orders_expiration_period

    # This affects whether it is possible to create a new order with the gateway.
    # If it's set to false, then it won't be possible to create a new order, but
    # it will keep checking on the existing ones.
    attr_accessor :active

    def self.find_by_hashed_id(s)
      self.find_by_id(s)
    end

    def initialize
      initialize_callbacks
      initialize_exchange_rate_adapters
      initialize_blockchain_adapters
      initialize_status_check_schedule
    end

    # Because this is a config based gateway, we only save last_keychain_id
    # and nothing more.
    def save
      save_last_keychain_id!
    end

    # Loads last_keychain_id from a file in the .straight dir.
    # If the file doesn't exist, we create it. Later, whenever an attribute is updated,
    # we save it to the file.
    def load_last_keychain_id!
      @last_keychain_id_file ||= StraightServer::Initializer::ConfigDir.path + "/#{name}_last_keychain_id"
      if File.exists?(@last_keychain_id_file)
        self.last_keychain_id = File.read(@last_keychain_id_file).to_i
      else
        self.last_keychain_id = 0
        save
      end
    end

    def save_last_keychain_id!
      @last_keychain_id_file ||= StraightServer::Initializer::ConfigDir.path + "/#{name}_last_keychain_id"
      File.open(@last_keychain_id_file, 'w') {|f| f.write(last_keychain_id) }
    end

    def address_provider
      Kernel.const_get("Straight::AddressProvider::#{@address_provider}")
    end

    # This method is a replacement for the Sequel's model one used in DB version of the gateway
    # and it finds gateways using the index of @@gateways Array.
    def self.find_by_id(id)
      @@gateways[id.to_i-1]
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
      gateway.pubkey                         = attrs['pubkey']
      gateway.confirmations_required         = attrs['confirmations_required'].to_i
      gateway.order_class                    = attrs['order_class']
      gateway.secret                         = attrs['secret']
      gateway.check_signature                = attrs['check_signature']
      gateway.callback_url                   = attrs['callback_url']
      gateway.default_currency               = attrs['default_currency']
      gateway.orders_expiration_period       = attrs['orders_expiration_period']
      gateway.active                         = attrs['active']
      gateway.address_provider               = attrs['address_provider'] || "Bip32"
      gateway.name                     = name
      gateway.id                       = i
      gateway.exchange_rate_adapter_names = attrs['exchange_rate_adapters']
      gateway.initialize_exchange_rate_adapters
      gateway.load_last_keychain_id!
      @@websockets[i] = {}
      @@gateways << gateway
    end if StraightServer::Config.gateways

  end

  # It may not be a perfect way to implement such a thing, but it gives enough flexibility to people
  # so they can simply start using a single gateway on their machines, a gateway which attributes are defined
  # in a config file instead of a DB. That way they don't need special tools to access the DB and create
  # a gateway, but can simply edit the config file.
  Gateway = if StraightServer::Config.gateways_source == 'config'
    GatewayOnConfig
  else
    GatewayOnDB
  end

end
