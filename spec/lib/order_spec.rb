require 'spec_helper'

RSpec.describe StraightServer::Order do

  before(:each) do

    # clean the database
    DB.run("DELETE FROM orders")
    @gateway = double("Straight Gateway mock")
    allow(@gateway).to receive(:id).and_return(1)
    allow(@gateway).to receive(:fetch_transactions_for).with("address").and_return([])
    @order   = StraightServer::Order.create(amount: 10, gateway_id: @gateway.id, address: 'address', keychain_id: 1)
    allow(@gateway).to receive(:order_status_changed).with(anything)
    allow(StraightServer::Gateway).to  receive(:find_by_id).and_return(@gateway)
  end

  describe "DB interaction" do

    it "saves a new order into the database" do
      expect(DB[:orders][:keychain_id => 1]).not_to be_nil 
    end

    it "updates an existing order" do
      expect(DB[:orders][:keychain_id => 1][:status]).to eq(0) 
      @order.status = 1
      @order.save
      expect(DB[:orders][:keychain_id => 1][:status]).to eq(1) 
    end

    it "finds first order in the database by id" do
      expect(StraightServer::Order.find(id: @order.id)).to equal_order(@order)
    end

    it "finds first order in the database by keychain_id" do
      expect(StraightServer::Order.find(keychain_id: @order.keychain_id)).to equal_order(@order)
    end

    it "finds orders in the database by any conditions" do
      order1 = StraightServer::Order.create(amount: 10, gateway_id: @gateway.id, address: 'address', keychain_id: 2)
      order2 = StraightServer::Order.create(amount: 10, gateway_id: @gateway.id, address: 'address', keychain_id: 3)
      
      expect(StraightServer::Order.where(keychain_id: 2).first).to equal_order(order1)
      expect(StraightServer::Order.where(keychain_id: 3).first).to equal_order(order2)
      expect(StraightServer::Order.where(keychain_id: 4).first).to be_nil

    end

    describe "with validations" do

      it "doesn't save order if the order with the same keychain_id exists"
      it "doesn't save order if the amount is invalid"
      it "doesn't save order if gateway_id is null"
      it "doesn't save order if address is null"

    end

  end

end
