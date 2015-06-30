require 'spec_helper'

RSpec.describe StraightServer::Gateway do

  before(:each) do
    @gateway = StraightServer::GatewayOnConfig.find_by_id(1)
    @order_mock = double("order mock")
    allow(@order_mock).to receive(:old_status)
    allow(@order_mock).to receive(:description=)
    allow(@order_mock).to receive(:set_amount_paid)
    allow(@order_mock).to receive(:reused).and_return(0)
    allow(@order_mock).to receive(:test_mode)
    [:id, :gateway=, :save, :to_h, :id=, :test_mode=, :test_mode].each { |m| allow(@order_mock).to receive(m) }
    @new_order_args = { amount: 1, keychain_id: 1, currency: nil, btc_denomination: nil }
  end

  it "sets order amount in satoshis calculated from another currency" do
    @gateway = StraightServer::GatewayOnConfig.find_by_id(2)
    allow(@gateway.exchange_rate_adapters.first).to receive(:rate_for).and_return(450.5412)
    expect(@gateway.create_order(amount: 2252.706, currency: 'USD').amount).to eq(500000000)
  end

  it "doesn't allow to create a new order if the gateway is inactive" do
    @gateway.active = false
    expect( -> { @gateway.create_order }).to raise_exception(StraightServer::GatewayModule::GatewayInactive)
    @gateway.active = true
  end

  it "loads blockchain adapters according to the config file" do
    gateway = StraightServer::GatewayOnConfig.find_by_id(2)
    expect(gateway.blockchain_adapters.map(&:class)).to eq([Straight::Blockchain::BlockchainInfoAdapter, Straight::Blockchain::MyceliumAdapter])
  end

  it "updates last_keychain_id to the new value provided in keychain_id if it's larger than the last_keychain_id" do
    gateway = StraightServer::GatewayOnConfig.find_by_id(2)
    gateway.create_order(amount: 2252.706, currency: 'BTC', keychain_id: 100)
    expect(gateway.last_keychain_id).to eq(100)
    gateway.create_order(amount: 2252.706, currency: 'BTC', keychain_id: 150)
    expect(gateway.last_keychain_id).to eq(150)
    gateway.create_order(amount: 2252.706, currency: 'BTC', keychain_id: 50)
  end

  it "only warns about an invalid Bitcoin address, but doesn't fail" do
    expect(StraightServer.logger).to receive(:warn) 
    allow_any_instance_of(Straight::Blockchain::MyceliumAdapter).to receive(:api_request).and_return(nil)
    # mainnet Bitcoin address, while we're on testnet
    expect(@gateway.fetch_transactions_for('12X3JTpcGPS1GXmuJn9gT3gspP6YFsFT6W')).to eq([])
  end

  context "reusing addresses" do

    # Config.reuse_address_orders_threshold for the test env is 5

    before(:each) do
      @gateway = StraightServer::GatewayOnConfig.find_by_id(2)
      allow(@gateway).to receive(:order_status_changed).with(anything).and_return([])
      allow(@gateway).to receive(:fetch_transactions_for).with(anything).and_return([])
      create_list(:order, 4, status: StraightServer::Order::STATUSES[:expired], gateway_id: @gateway.id)
      create_list(:order, 2, status: StraightServer::Order::STATUSES[:paid],    gateway_id: @gateway.id)
      @expired_orders_1 = create_list(:order, 5, status: StraightServer::Order::STATUSES[:expired], gateway_id: @gateway.id)
      @expired_orders_2 = create_list(:order, 2, status: StraightServer::Order::STATUSES[:expired], gateway_id: @gateway.id)
    end

    it "finds all expired orders that follow in a row" do
      expect(@gateway.send(:find_expired_orders_row).size).to eq(5)
      expect(@gateway.send(:find_expired_orders_row).map(&:id)).to     include(*@expired_orders_1.map(&:id))
      expect(@gateway.send(:find_expired_orders_row).map(&:id)).not_to include(*@expired_orders_2.map(&:id))
    end

    it "picks an expired order which address is going to be reused" do
      expect(@gateway.find_reusable_order).to eq(@expired_orders_1.last)
    end

    it "picks an expired order which address is going to be reused only when this address received no transactions" do
      allow(@gateway).to receive(:fetch_transactions_for).with(@expired_orders_1.last.address).and_return(['transaction'])
      expect(@gateway.find_reusable_order).to eq(nil)
    end

    it "creates a new order with a reused address" do
      reused_order = @expired_orders_1.last
      order        = @gateway.create_order(amount: 2252.706, currency: 'BTC')
      expect(order.keychain_id).to eq(reused_order.keychain_id)
      expect(order.address).to     eq(@gateway.address_provider.new_address(keychain_id: reused_order.keychain_id))
      expect(order.reused).to      eq(1)
    end

    it "doesn't increment last_keychain_id if order is reused" do
      last_keychain_id = @gateway.last_keychain_id
      order = @gateway.create_order(amount: 2252.706, currency: 'BTC')
      expect(@gateway.last_keychain_id).to eq(last_keychain_id)

      order.status = StraightServer::Order::STATUSES[:paid]
      order.save
      order_2 = @gateway.create_order(amount: 2252.706, currency: 'BTC')
      expect(@gateway.last_keychain_id).to eq(last_keychain_id+1)
    end

    it "after the reused order was paid, gives next order a new keychain_id" do
      order = @gateway.create_order(amount: 2252.706, currency: 'BTC')
      order.status = StraightServer::Order::STATUSES[:expired]
      order.save
      expect(order.keychain_id).to eq(@expired_orders_1.last.keychain_id)

      order = @gateway.create_order(amount: 2252.706, currency: 'BTC')
      order.status = StraightServer::Order::STATUSES[:paid]
      order.save
      expect(@gateway.send(:find_expired_orders_row).map(&:id)).to be_empty
    end

  end

  context "callback url" do

    before(:each) do
      @gateway = StraightServer::GatewayOnConfig.find_by_id(2)
      @order = build(:order, gateway: @gateway, address: 'address_1', keychain_id: 1, id: 1)
      allow(@order).to receive(:status).and_return(1)
      allow(@order).to receive(:tid).and_return('tid1')
    end

    it "sends a request to the callback_url and saves response" do
      stub_request(:get, 'http://localhost:3001/payment-callback?address=address_1&amount=10&amount_in_btc=0.0000001&amount_paid_in_btc=0.&keychain_id=1&last_keychain_id=0&order_id=1&status=1&tid=tid1').
        with(headers: {'X-Signature' => 'waGfkiy5VdiAjOfzMXp4ShRF5FaOy7BfIKWzryKhNKVWdCToqTC2vt9aE/FNqc0mjVqAh3uQBfyRdC1YYPFr6g=='}).
        to_return(status: 200, body: 'okay')
      expect(@gateway).to receive(:sleep).exactly(0).times
      @gateway.order_status_changed(@order)
      expect(@order.callback_response).to eq(code: '200', body: 'okay')
    end

    it "keeps sending request according to the callback schedule if there's an error" do
      stub_request(:get, 'http://localhost:3001/payment-callback?address=address_1&amount=10&amount_in_btc=0.0000001&amount_paid_in_btc=0.&keychain_id=1&last_keychain_id=0&order_id=1&status=1&tid=tid1').
        with(headers: {'X-Signature' => 'waGfkiy5VdiAjOfzMXp4ShRF5FaOy7BfIKWzryKhNKVWdCToqTC2vt9aE/FNqc0mjVqAh3uQBfyRdC1YYPFr6g=='}).
        to_return(status: 404, body: '')
      expect(@gateway).to receive(:sleep).exactly(10).times
      @gateway.order_status_changed(@order)
    end

    it "receives random data in :data params and sends it back in a callback request" do
      uri = "/payment-callback?order_id=1&amount=10&amount_in_btc=0.0000001&amount_paid_in_btc=0.&status=1&address=address_1&tid=tid1&keychain_id=1&last_keychain_id=1&callback_data=so%3Fme+ran%26dom+data"
      signature = 'S2P8A16+RPaegTzJnb0Eg91csb1SExjdnvadABmQvfoIry4POBp6WbA6UOSqXojzRevyC8Ya/5QrQTnNxIb4og=='
      expect(StraightServer::SignatureValidator.signature(nonce: nil, body: nil, method: 'GET', request_uri: uri, secret: @gateway.secret)).to eq signature
      stub_request(:get, "http://localhost:3001#{uri}").with(headers: {'X-Signature' => signature}).to_return(status: 200, body: '')
      expect(@gateway).to receive(:new_order).with(@new_order_args).once.and_return(@order)
      @gateway.create_order(amount: 1, callback_data: 'so?me ran&dom data')
      @gateway.order_status_changed(@order)
    end

    it "uses callback_url from order when making callback" do
      uri = '/?with=params&order_id=1&amount=10&amount_in_btc=0.0000001&amount_paid_in_btc=0.&status=1&address=address_1&tid=tid1&keychain_id=1&last_keychain_id=0'
      signature = 'jCCEthsR0XsdDtMfEFBn1+G+XxoVTH1noO4yrdGUBJwH3ysF9QDuPGwWDlgrSqrEyxbJB1KoBIBbcRxaAE2iZA=='
      expect(StraightServer::SignatureValidator.signature(nonce: nil, body: nil, method: 'GET', request_uri: uri, secret: @gateway.secret)).to eq signature
      stub_request(:get, "http://new_url#{uri}").with(headers: {'X-Signature' => signature}).to_return(status: 200, body: '')
      @order.callback_url = 'http://new_url?with=params'
      @gateway.order_status_changed(@order)
    end
  end

  describe "order counters" do

    it "uses 0 for non-existent order counters and increments them" do
      expect(@gateway.order_counters(reload: true)).to include({ new: 0, unconfirmed: 0, paid: 0, underpaid: 0, overpaid: 0, expired: 0 })
      @gateway.increment_order_counter!(:new)
      expect(@gateway.order_counters(reload: true)[:new]).to eq(1)
    end

    it "raises exception when trying to access counters but the feature is disabled" do
      allow(StraightServer::Config).to receive(:count_orders).and_return(false)
      expect( -> { @gateway.order_counters(reload: true) }).to raise_exception(StraightServer::Gateway::OrderCountersDisabled)
      expect( -> { @gateway.increment_order_counter!(:new) }).to raise_exception(StraightServer::Gateway::OrderCountersDisabled)
    end

    it "updates gateway's order counters when an associated order status changes" do
      allow_any_instance_of(StraightServer::Order).to receive(:transaction).and_return({ tid: 'xxx' })
      allow(@gateway).to receive(:send_callback_http_request)
      allow(@gateway).to receive(:send_order_to_websocket_client)

      expect(@gateway.order_counters(reload: true)).to eq({ new: 0, unconfirmed: 0, paid: 0, underpaid: 0, overpaid: 0, expired: 0, canceled: 0 })
      order = create(:order, gateway_id: @gateway.id)
      expect(@gateway.order_counters(reload: true)).to eq({ new: 1, unconfirmed: 0, paid: 0, underpaid: 0, overpaid: 0, expired: 0, canceled: 0 })
      order.status = 2
      expect(@gateway.order_counters(reload: true)).to eq({ new: 0, unconfirmed: 0, paid: 1, underpaid: 0, overpaid: 0, expired: 0, canceled: 0 })

      expect(@gateway.order_counters(reload: true)).to eq({ new: 0, unconfirmed: 0, paid: 1, underpaid: 0, overpaid: 0, expired: 0, canceled: 0 })
      order = create(:order, gateway_id: @gateway.id)
      expect(@gateway.order_counters(reload: true)).to eq({ new: 1, unconfirmed: 0, paid: 1, underpaid: 0, overpaid: 0, expired: 0, canceled: 0 })
      order.status = 1
      expect(@gateway.order_counters(reload: true)).to eq({ new: 0, unconfirmed: 1, paid: 1, underpaid: 0, overpaid: 0, expired: 0, canceled: 0 })
      order.status = 5
      expect(@gateway.order_counters(reload: true)).to eq({ new: 0, unconfirmed: 0, paid: 1, underpaid: 0, overpaid: 0, expired: 1, canceled: 0 })
    end

    it "doesn't increment orders on status update unless the option is turned on (but no exception raised)" do
      allow(StraightServer::Config).to receive(:count_orders).and_return(false)
      allow_any_instance_of(StraightServer::Order).to receive(:transaction).and_return({ tid: 'xxx' })
      allow(@gateway).to receive(:send_callback_http_request)
      allow(@gateway).to receive(:send_order_to_websocket_client)
      order = create(:order, gateway_id: @gateway.id)
      expect(StraightServer.redis_connection.get("#{StraightServer::Config.redis[:prefix]}:gateway_#{@gateway.id}:new_orders_counter")).to be_nil
    end

  end

  describe "config based gateway" do

    it "loads all the gateways from the config file and assigns correct attributes" do
      gateway1 = StraightServer::GatewayOnConfig.find_by_id(1)
      gateway2 = StraightServer::GatewayOnConfig.find_by_id(2)
      expect(gateway1).to be_kind_of(StraightServer::GatewayOnConfig)
      expect(gateway2).to be_kind_of(StraightServer::GatewayOnConfig)

      expect(gateway1.pubkey).to eq('xpub6Arp6y5VVQzq3LWTHz7gGsGKAdM697RwpWgauxmyCybncqoAYim6P63AasNKSy3VUAYXFj7tN2FZ9CM9W7yTfmerdtAPU4amuSNjEKyDeo6')
      expect(gateway1.confirmations_required).to eq(0)
      expect(gateway1.order_class).to eq("StraightServer::Order")
      expect(gateway1.name).to eq("default")

      expect(gateway2.pubkey).to eq('xpub6AH1Ymkkrwk3TaMrVrXBCpcGajKc9a1dAJBTKr1i4GwYLgLk7WDvPtN1o1cAqS5DZ9CYzn3gZtT7BHEP4Qpsz24UELTncPY1Zsscsm3ajmX')
      expect(gateway2.confirmations_required).to eq(0)
      expect(gateway2.order_class).to eq("StraightServer::Order")
      expect(gateway2.name).to eq("second_gateway")
    end

    it "saves and retrieves last_keychain_id from the file in the .straight dir" do
      @gateway = StraightServer::GatewayOnConfig.find_by_id(2)
      @gateway.check_signature = false
      @gateway.save
      expect(File.read("#{ENV['HOME']}/.straight/second_gateway_last_keychain_id").to_i).to eq(0)
      @gateway.update_last_keychain_id
      @gateway.save
      expect(File.read("#{ENV['HOME']}/.straight/second_gateway_last_keychain_id").to_i).to eq(1)

      expect(@gateway).to receive(:new_order).with(@new_order_args.merge({ keychain_id: 2})).once.and_return(@order_mock)
      @gateway.create_order(amount: 1)
      expect(File.read("#{ENV['HOME']}/.straight/second_gateway_last_keychain_id").to_i).to eq(2)
    end

    it "searches for Gateway using regular ids when find_by_hashed_id method is called" do
      expect(StraightServer::GatewayOnConfig.find_by_hashed_id(1)).not_to be_nil
    end

    it "set test mode `on` based on config" do
      expect(@gateway.test_mode).to be true
    end

    it "set test mode `off`" do
      @gateway = StraightServer::GatewayOnConfig.find_by_id(2)
      expect(@gateway.test_mode).to be false
    end

    it "using testnet when test mode is enabled" do
      @gateway = StraightServer::GatewayOnConfig.find_by_id(1)
      testnet_adapter = Straight::Blockchain::MyceliumAdapter.testnet_adapter
      expect(@gateway.blockchain_adapters.first.instance_variable_get(:@base_url))
        .to eq(testnet_adapter.instance_variable_get(:@base_url))
    end

    it "disable test mode manually" do
      @gateway = StraightServer::GatewayOnConfig.find_by_id(1)
      @gateway.test_mode = false
      expect(@gateway.blockchain_adapters).to_not eq([Straight::Blockchain::MyceliumAdapter.testnet_adapter])
    end

    it "save test_last_keychain_id file with approciate data" do
      gateway = StraightServer::GatewayOnConfig.find_by_id(1)
      gateway.check_signature = false
      gateway.save
      expect(File.read("#{ENV['HOME']}/.straight/default_test_last_keychain_id").to_i).to eq(0)
      gateway.update_last_keychain_id
      gateway.save
      expect(File.read("#{ENV['HOME']}/.straight/default_test_last_keychain_id").to_i).to eq(1)
    end

  end

  describe "db based gateway" do

    before(:each) do
      # clean the database
      DB.run("DELETE FROM gateways")

      @gateway = StraightServer::GatewayOnDB.new(
        confirmations_required: 0,
        pubkey:      'xpub-000',
        order_class: 'StraightServer::Order',
        secret:      'secret',
        name:        'default',
        check_signature: true,
        exchange_rate_adapter_names: ['Bitpay', 'Coinbase', 'Bitstamp']
      )
    end

    it "saves and retrieves last_keychain_id from the db" do
      @gateway.check_signature = false
      @gateway.save
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(0)
      @gateway.update_last_keychain_id
      @gateway.save
      @gateway.refresh
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(1)

      expect(@gateway).to receive(:new_order).with(@new_order_args.merge({ keychain_id: 2})).once.and_return(@order_mock)
      @gateway.create_order(amount: 1)
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(2)
    end

    it "encryptes and decrypts the gateway secret" do
      expect(@gateway.save)
      expect(@gateway[:secret]).to eq("96c1c24edff5c1c2:6THJEZqg+2qlDhtWE2Tytg==")
      expect(@gateway.secret).to eq("secret")
    end

    it "re-encrypts the new gateway secrect if it was changed" do
      @gateway.save
      @gateway.update(secret: 'new secret', update_secret: true)
      expect(@gateway.secret).to eq("new secret")
    end

    it "finds orders using #find_by_id method which is essentially an alias for Gateway[]" do
      @gateway.save
      expect(StraightServer::GatewayOnDB.find_by_id(@gateway.id)).to eq(@gateway)
    end

    it "assigns hashed_id to gateway and then finds gateway using that value" do
      @gateway.save
      hashed_id = hmac_sha256(@gateway.id, 'global server secret')
      expect(@gateway.hashed_id).to eq(hashed_id)
      expect(StraightServer::GatewayOnDB.find_by_hashed_id(hashed_id)).to eq(@gateway)
    end

    context "test mode" do

      before(:each) do
        @gateway.test_pubkey = "txpub"
      end
      
      it "not activate after created" do
        @gateway.save
        expect(@gateway.test_mode).to be false
      end

      it "not using testnet adapter by default" do
        @gateway.save
        expect(@gateway.blockchain_adapters).to_not eq([Straight::Blockchain::MyceliumAdapter.testnet_adapter])
      end

      it "activated if mode is specified explicity" do
        @gateway.test_mode = true
        @gateway.save
        @gateway.refresh
        expect(@gateway.test_mode).to be true
        expect(@gateway.blockchain_adapters.map(&:class)).to eq([Straight::Blockchain::MyceliumAdapter])
      end

      it "enabled and not saved" do
        @gateway.save
        @gateway.enable_test_mode!
        expect(@gateway.test_mode).to be true
        @gateway.refresh
        expect(@gateway.test_mode).to be false
      end

      it "enabled and saved" do
        @gateway.save
        @gateway.enable_test_mode!
        expect(@gateway.test_mode).to be true
        @gateway.refresh
        expect(@gateway.test_mode).to be false
      end

      it "enabled and saved" do
        @gateway[:test_mode] = false
        expect(@gateway.test_mode).to eq false
        @gateway.enable_test_mode!
        @gateway.save
        @gateway.refresh
        expect(@gateway.test_mode).to be true
      end
      
      it "field updates in mass assigment" do
        @gateway.save
        fields = {test_mode: true}
        @gateway.update(fields)
        @gateway.refresh
        expect(@gateway.test_mode).to be true
      end

      it "update test_last_keychain_id" do
        @gateway.check_signature = false
        @gateway.enable_test_mode!
        @gateway.save
        @gateway.refresh

        expect(@gateway).to receive(:new_order).with(@new_order_args).once.and_return(@order_mock)
        @gateway.create_order(amount: 1)
        expect(DB[:gateways][:name => 'default'][:test_last_keychain_id]).to eq(1)
      end
      
      it "validate that test public key is provided when saving with test mode flag" do
        @gateway = StraightServer::GatewayOnDB.new(
          confirmations_required: 0,
          pubkey:      'xpub-000',
          test_mode:   true
        )
        expect(@gateway.valid?).to be false
        expect(@gateway.errors[:test_pubkey]).to_not be_empty
      end

      it "doesn't require pubkey in test mode" do
        @gateway = StraightServer::GatewayOnDB.new(
          test_pubkey: 'xpub-000',
          test_mode:   true,
        )
        expect(@gateway.valid?).to be true
        @gateway.test_mode = false
        expect(@gateway.valid?).to be false
      end
    end
  end

  describe "handling websockets" do

    before(:each) do
      StraightServer::GatewayModule.class_variable_set(:@@websockets, { @gateway.id => {} })
      @ws = double("websocket mock")
      allow(@ws).to receive(:on).with(:close)
      allow(@order_mock).to receive(:id).and_return(1)
      allow(@order_mock).to receive(:status).and_return(0)
    end

    it "adds a new websocket for the order" do
      @gateway.add_websocket_for_order(@ws, @order_mock)
      expect(@gateway.websockets).to eq({1 => @ws})
    end

    it "sends a message to the websocket when status of the order is changed and closes the connection" do
      allow(@gateway).to receive(:send_callback_http_request) # ignoring the callback which sends an callback_url request
      expect(@order_mock).to receive(:to_json).and_return("order json info")
      expect(@ws).to receive(:send).with("order json info")
      expect(@ws).to receive(:close)
      @gateway.add_websocket_for_order(@ws, @order_mock)
      @gateway.order_status_changed(@order_mock)
    end

    it "doesn't allow to listen to orders with statuses other than 0 or 1" do
      allow(@order_mock).to receive(:status).and_return(2)
      expect( -> { @gateway.add_websocket_for_order(@ws, @order_mock) }).to raise_exception(StraightServer::Gateway::WebsocketForCompletedOrder)
    end

    it "doesn't allow to create a second websocket for the same order" do
      allow(@order_mock).to receive(:status).and_return(0)
      @gateway.add_websocket_for_order(@ws, @order_mock)
      expect( -> { @gateway.add_websocket_for_order(@ws, @order_mock) }).to raise_exception(StraightServer::Gateway::WebsocketExists)
    end

  end

  def hmac_sha256(key, secret)
    OpenSSL::HMAC.digest('sha256', secret, key.to_s).unpack("H*").first
  end

end
