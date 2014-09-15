require 'spec_helper'

RSpec.describe StraightServer::Order do

  before(:each) do

    # clean the database
    DB.run("DELETE FROM orders")

    @gateway = double("Straight Gateway mock")
    @order   = StraightServer::Order.new(amount: 10, gateway: @gateway, address: 'address', keychain_id: 1)
    allow(@gateway).to receive(:order_status_changed).with(@order)
    allow(@gateway).to receive(:id).and_return(1)
    allow(StraightServer::Gateway).to  receive(:find_by_id).and_return(@gateway)
  end

  describe "DB interaction" do

    it "saves order into the database" do
      expect(@order.save).to be_truthy
      orders = DB[:orders]
      expect(orders[:keychain_id => 1]).not_to be_nil 
    end

    it "finds first order in the database by id" do
      @order.save
      expect(StraightServer::Order.find_by_id(@order.id)).to equal_order(@order)
    end

    it "finds first order in the database by keychain_id" do
      @order.save
      expect(StraightServer::Order.find_by_keychain_id(@order.keychain_id)).to equal_order(@order)
    end

    it "finds orders in the database by any conditions" do
      order1 = StraightServer::Order.new(amount: 10, gateway: @gateway, address: 'address', keychain_id: 1)
      order2 = StraightServer::Order.new(amount: 10, gateway: @gateway, address: 'address', keychain_id: 2)
      order1.save
      order2.save

      expect(StraightServer::Order.find(keychain_id: 1).first).to equal_order(order1)
      expect(StraightServer::Order.find(keychain_id: 2).first).to equal_order(order2)
      expect(StraightServer::Order.find(keychain_id: 3).first).to be_nil

    end

    describe "with validations" do

      it "doesn't save order if the order with the same keychain_id exists"
      it "doesn't save order if the amount is invalid"
      it "doesn't save order if gateway_id is null"
      it "doesn't save order if address is null"

    end

  end

end
