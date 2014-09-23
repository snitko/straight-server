require 'spec_helper'

RSpec.describe StraightServer::Gateway do

  before(:each) do
    @gateway = StraightServer::GatewayOnConfig.find_by_id(1)
  end

  it "checks for signature when creating a new order" do
    @gateway.last_keychain_id = 0
    expect( -> { @gateway.create_order(amount: 1, signature: 'invalid', id: 1) }).to raise_exception(StraightServer::GatewayModule::InvalidSignature)
    expect(@gateway).to receive(:order_for_keychain_id).with(amount: 1, keychain_id: 1, id: 1).once
    @gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'), id: 1)
  end

  it "checks md5 signature only if that setting is set ON for a particular gateway" do
    gateway1 = StraightServer::GatewayOnConfig.find_by_id(1)
    gateway2 = StraightServer::GatewayOnConfig.find_by_id(2)
    expect(gateway2).to receive(:order_for_keychain_id).with(amount: 1, keychain_id: 1, id: 1).once
    expect( -> { gateway1.create_order(amount: 1, signature: 'invalid', id: 1) }).to raise_exception(StraightServer::GatewayModule::InvalidSignature)
    expect( -> { gateway2.create_order(amount: 1, signature: 'invalid', id: 1) }).not_to raise_exception()
  end

  it "doesn't allow nil or empty order id if signature checks are enabled" do
    expect( -> { @gateway.create_order(amount: 1, signature: 'invalid', id: nil) }).to raise_exception(StraightServer::GatewayModule::InvalidOrderId)
    expect( -> { @gateway.create_order(amount: 1, signature: 'invalid', id: '') }).to raise_exception(StraightServer::GatewayModule::InvalidOrderId)
  end

  context "callback url" do

    before(:each) do
      @response_mock = double("http response mock")
      @order = create(:order)
      allow(@order).to receive(:status).and_return(1)
    end

    it "sends a request to the callback_url" do
      allow(@response_mock).to receive(:status).and_return(["200", "OK"])
      expect(URI).to receive_message_chain(:parse, :read).and_return(@response_mock)
      @gateway.order_status_changed(@order)
    end

    it "keeps sending request according to the callback schedule if there's an en error" do
      allow(@response_mock).to receive(:status).and_return(["404", "OK"])
      uri_mock = double("URI mock")
      allow(@gateway).to receive(:sleep).exactly(10).times
      expect(uri_mock).to receive(:read).exactly(11).times.and_return(@response_mock)
      expect(URI).to receive(:parse).with('http://localhost:3000/payment-callback?' + @order.to_http_params).exactly(11).times.and_return(uri_mock)
      @gateway.order_status_changed(@order)
    end

  end

  describe "config based gateway" do

    it "loads all the gateways from the config file and assigns correct attributes" do
      gateway1 = StraightServer::GatewayOnConfig.find_by_id(1)
      gateway2 = StraightServer::GatewayOnConfig.find_by_id(2)
      expect(gateway1).to be_kind_of(StraightServer::GatewayOnConfig)
      expect(gateway2).to be_kind_of(StraightServer::GatewayOnConfig)

      expect(gateway1.pubkey).to eq('xpub-000') 
      expect(gateway1.confirmations_required).to eq(0) 
      expect(gateway1.order_class).to eq("StraightServer::Order") 
      expect(gateway1.name).to eq("default") 

      expect(gateway2.pubkey).to eq('xpub-001') 
      expect(gateway2.confirmations_required).to eq(0) 
      expect(gateway2.order_class).to eq("StraightServer::Order") 
      expect(gateway2.name).to eq("second_gateway") 
    end

    it "saves and retrieves last_keychain_id from the file in the .straight dir" do
      expect(File.read("#{ENV['HOME']}/.straight/default_last_keychain_id").to_i).to eq(0)
      @gateway.increment_last_keychain_id!
      expect(File.read("#{ENV['HOME']}/.straight/default_last_keychain_id").to_i).to eq(1)

      expect(@gateway).to receive(:order_for_keychain_id).with(amount: 1, keychain_id: 2, id: 1).once
      @gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'), id: 1)
      expect(File.read("#{ENV['HOME']}/.straight/default_last_keychain_id").to_i).to eq(2)
    end

  end

  describe "db based gateway" do

    before(:each) do
      @gateway = StraightServer::GatewayOnDB.create(
        confirmations_required: 0,
        pubkey:      'xpub-000',
        order_class: 'StraightServer::Order',
        secret:      'secret',
        name:        'default',
        check_signature: true
      )
    end
    
    it "saves and retrieves last_keychain_id from the db" do
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(0)
      @gateway.increment_last_keychain_id!
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(1)

      expect(@gateway).to receive(:order_for_keychain_id).with(amount: 1, keychain_id: 2, id: 1).once
      @gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'), id: 1)
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(2)
    end

  end

end
