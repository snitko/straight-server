require 'spec_helper'

RSpec.describe StraightServer::Gateway do

  before(:each) do
    @gateway = StraightServer::GatewayOnConfig.find_by_id(1)
  end

  it "checks for signature when creating a new order" do
    @gateway.last_keychain_id = 0
    expect( -> { @gateway.create_order(amount: 1, signature: 'invalid') }).to raise_exception(StraightServer::GatewayModule::InvalidSignature)
    expect(@gateway).to receive(:order_for_id).with(amount: 1, keychain_id: 1).once
    @gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'))
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

      expect(@gateway).to receive(:order_for_id).with(amount: 1, keychain_id: 2).once
      @gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'))
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
        name:        'default'
      )
    end
    
    it "saves and retrieves last_keychain_id from the db" do
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(0)
      @gateway.increment_last_keychain_id!
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(1)

      expect(@gateway).to receive(:order_for_id).with(amount: 1, keychain_id: 2).once
      @gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'))
      expect(DB[:gateways][:name => 'default'][:last_keychain_id]).to eq(2)
    end

  end

end
