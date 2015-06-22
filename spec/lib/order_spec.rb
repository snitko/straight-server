# coding: utf-8
require 'spec_helper'

RSpec.describe StraightServer::Order do

  before(:each) do
    # clean the database
    DB.run("DELETE FROM orders")
    @gateway = double("Straight Gateway mock")
    allow(@gateway).to receive(:id).and_return(1)
    allow(@gateway).to receive(:active).and_return(true)
    allow(@gateway).to receive(:order_status_changed)
    allow(@gateway).to receive(:save)
    allow(@gateway).to receive(:increment_order_counter!)
    allow(@gateway).to receive(:current_exchange_rate).and_return(111)
    allow(@gateway).to receive(:default_currency).and_return('USD')
    allow(@gateway).to receive(:last_keychain_id).and_return(222)
    @order = create(:order, gateway_id: @gateway.id)
    allow(@gateway).to receive(:fetch_transactions_for).with(anything).and_return([])
    allow(@gateway).to receive(:order_status_changed).with(anything)
    allow(@gateway).to receive(:sign_with_secret).with(anything).and_return("1", "2", "3")
    allow(StraightServer::Gateway).to receive(:find_by_id).and_return(@gateway)

    websockets = {}
    StraightServer::GatewayOnConfig.class_variable_get(:@@gateways).each do |g|
      websockets[g.id] = {}
    end
    StraightServer::GatewayModule.class_variable_set(:@@websockets, websockets)
  end

  it "prepares data as http params" do
    allow(@order).to receive(:tid).and_return("tid1")
    expect(@order.to_http_params).to eq("order_id=#{@order.id}&amount=10&amount_in_btc=#{@order.amount_in_btc(as: :string)}&amount_paid_in_btc=#{@order.amount_in_btc(field: @order.amount_paid, as: :string)}&status=#{@order.status}&address=#{@order.address}&tid=tid1&keychain_id=#{@order.keychain_id}&last_keychain_id=#{@order.gateway.last_keychain_id}")
  end

  it "generates a payment_id" do
    expect(@order.payment_id).not_to be_nil
  end

  it "starts a periodic status check but subtracts the time passed from order creation from the duration of the check" do
    expect(@order).to receive(:check_status_on_schedule).with(duration: 900)
    @order.start_periodic_status_check

    @order.created_at = (Time.now - 100)
    expect(@order).to receive(:check_status_on_schedule).with(duration: 800)
    @order.start_periodic_status_check
  end

  it "checks DB for a status update first if the respective option for the gateway is turned on" do
    # allow(@order).to receive(:transaction).and_raise("Shouldn't ever be happening!")
    StraightServer::Config.check_order_status_in_db_first = true
    StraightServer::Order.where(id: @order.id).update(status: 2)
    allow(@order.gateway).to receive(:fetch_transactions_for).and_return([])
    allow(@order.gateway).to receive(:order_status_changed)
    expect(@order.status(reload: false)).to eq(0)
    expect(@order.status(reload: true)).to eq(2)
  end

  it "updates order status when the time in which it expires passes (periodic status checks finish)" do
    allow(@order).to receive(:status=) do
      expect(@order).to receive(:status_changed?).and_return(true)
      expect(@order).to receive(:save)
    end
    allow(@order).to receive(:check_status_on_schedule).with(duration: 900) { @order.status = 5 }
    @order.start_periodic_status_check
  end

  it "doesn't allow to create an order for inactive gateway" do
    allow(@gateway).to receive(:active).and_return(false)
    expect( -> { create(:order, gateway_id: @gateway.id) }).to raise_exception(Sequel::ValidationFailed, "gateway is inactive, cannot create order for inactive gateway")
  end

  it "adds exchange rate at the moment of purchase to the data hash" do
    order = create(:order, gateway_id: @gateway.id)
    expect(order.data[:exchange_rate]).to eq({ price: 111, currency: 'USD' })
  end

  it "returns last_keychain_id for the gateway along with other order data" do
    order = create(:order, gateway_id: @gateway.id)
    expect(order.to_h).to include(keychain_id: order.keychain_id, last_keychain_id: @gateway.last_keychain_id)
  end

  it 'is cancelable only while new' do
    order = build(:order, gateway_id: @gateway.id, status: 0)
    expect(order.cancelable?).to eq true
    (1..6).each do |status|
      order.instance_variable_set :@status, status
      expect(order.cancelable?).to eq false
    end
  end

  describe "DB interaction" do

    it "saves a new order into the database" do
      expect(DB[:orders][:keychain_id => @order.id]).not_to be_nil
    end

    it "updates an existing order" do
      allow(@order).to receive(:gateway).and_return(@gateway)
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

      it "doesn't save order if the amount is invalid" do
        expect( -> { create(:order, amount: 0) }).to raise_error()
      end

      it "doesn't save order if gateway_id is invalid" do
        expect( -> { create(:order, gateway_id: 0) }).to raise_error()
      end

      it "doesn't save order if description is too long" do
        expect( -> { create(:order, description: ("text" * 100)) }).to raise_error()
      end

    end

  end

end
