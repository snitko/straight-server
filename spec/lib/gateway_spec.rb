require 'spec_helper'

RSpec.describe StraightServer::Gateway do

  it "loads all the gateways from the config file and assigns correct attributes" do
    gateway1 = StraightServer::Gateway.find_by_id(1)
    gateway2 = StraightServer::Gateway.find_by_id(2)
    expect(gateway1).to be_kind_of(StraightServer::Gateway)
    expect(gateway2).to be_kind_of(StraightServer::Gateway)

    expect(gateway1.pubkey).to eq('xpub-000') 
    expect(gateway1.confirmations_required).to eq(0) 
    expect(gateway1.order_class).to eq("StraightServer::Order") 
    expect(gateway1.name).to eq("default") 

    expect(gateway2.pubkey).to eq('xpub-001') 
    expect(gateway2.confirmations_required).to eq(0) 
    expect(gateway2.order_class).to eq("StraightServer::Order") 
    expect(gateway2.name).to eq("second_gateway") 
    
  end

  it "checks for signature when creating a new order" do
    gateway = StraightServer::Gateway.find_by_id(1)
    gateway.last_keychain_id = 0
    expect( -> { gateway.create_order(amount: 1, signature: 'invalid') }).to raise_exception(StraightServer::GatewayModule::InvalidSignature)
    expect(gateway).to receive(:order_for_id).with(amount: 1, keychain_id: 1).once
    gateway.create_order(amount: 1, signature: Digest::MD5.hexdigest('1secret'))
  end

end
