require 'spec_helper'

RSpec.describe StraightServer::Order do

  before(:each) do
    # clean the database
    DB.run("DELETE FROM orders")
    @gateway = double("Straight Gateway mock")
    allow(@gateway).to receive(:id).and_return(1)
    @order = create(:order, gateway_id: @gateway.id)
    allow(@gateway).to receive(:fetch_transactions_for).with(anything).and_return([])
    allow(@gateway).to receive(:order_status_changed).with(anything)
    allow(StraightServer::Gateway).to receive(:find_by_id).and_return(@gateway)
  end

  describe "DB interaction" do

    it "saves a new order into the database" do
      expect(DB[:orders][:keychain_id => 1]).not_to be_nil 
    end

    it "updates an existing order" do
      expect(DB[:orders][:keychain_id => @order.id][:status]).to eq(0) 
      @order.status = 1
      @order.save
      expect(DB[:orders][:keychain_id => @order.id][:status]).to eq(1) 
    end

    it "finds first order in the database by id" do
      expect(StraightServer::Order.find(id: @order.id)).to equal_order(@order)
    end

    it "finds first order in the database by keychain_id" do
      expect(StraightServer::Order.find(keychain_id: @order.keychain_id)).to equal_order(@order)
    end

    it "finds orders in the database by any conditions" do
      order1 = create(:order, gateway_id: @gateway.id)
      order2 = create(:order, gateway_id: @gateway.id)
      
      expect(StraightServer::Order.where(keychain_id: order1.keychain_id).first).to equal_order(order1)
      expect(StraightServer::Order.where(keychain_id: order2.keychain_id).first).to equal_order(order2)
      expect(StraightServer::Order.where(keychain_id: order2.keychain_id+1).first).to be_nil

    end

    describe "with validations" do

      it "doesn't save order if the order with the same id exists" do
        order = create(:order, gateway_id: @gateway.id)
        expect( -> { create(:order, id: order.id, gateway_id: @gateway.id) }).to raise_error()
      end

      it "doesn't save order if the order with the same address exists" do
        order = create(:order, gateway_id: @gateway.id)
        expect( -> { create(:order, address: order.address) }).to raise_error()
      end

      it "doesn't save order if the order with the same keychain_id and gateway_id exists" do
        order = create(:order, gateway_id: @gateway.id)
        expect( -> { create(:order, keychain_id: order.id, gateway_id: order.gateway_id+1) }).not_to raise_error()
        expect( -> { create(:order, keychain_id: order.id, gateway_id: order.gateway_id)   }).to     raise_error()
      end

      it "doesn't save order if the amount is invalid" do
        expect( -> { create(:order, amount: 0) }).to raise_error()
      end

      it "doesn't save order if gateway_id is invalid" do
        expect( -> { create(:order, gateway_id: 0) }).to raise_error()
      end

    end

  end

end
