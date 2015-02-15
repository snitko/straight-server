require 'spec_helper'

RSpec.describe StraightServer::Order do

  before(:each) do
    # clean the database
    DB.run("DELETE FROM orders")
    @gateway = double("Straight Gateway mock")
    allow(@gateway).to receive(:id).and_return(1)
    allow(@gateway).to receive(:active).and_return(true)
    @order = create(:order, gateway_id: @gateway.id)
    allow(@gateway).to receive(:fetch_transactions_for).with(anything).and_return([])
    allow(@gateway).to receive(:order_status_changed).with(anything)
    allow(@gateway).to receive(:sign_with_secret).with(anything).and_return("1", "2", "3")
    allow(StraightServer::Gateway).to receive(:find_by_id).and_return(@gateway)
  end

  it "prepares data as http params" do
    allow(@order).to receive(:tid).and_return("tid1")
    expect(@order.to_http_params).to eq("order_id=#{@order.id}&amount=10&status=#{@order.status}&address=#{@order.address}&tid=tid1")
  end

  it "generates a payment_id" do
    expect(@order.payment_id).to eq(@order.gateway.sign_with_secret("#{@order.id}#{@order.amount}#{@order.created_at}"))
  end

  it "starts a periodic status check but subtracts the time passed from order creation from the duration of the check" do
    expect(@order).to receive(:check_status_on_schedule).with(duration: 900)
    @order.start_periodic_status_check

    @order.created_at = (Time.now - 100)
    expect(@order).to receive(:check_status_on_schedule).with(duration: 800)
    @order.start_periodic_status_check
  end

  it "checks DB for a status update first if there respective option for the gateway is turned on" do
    @order.gateway.check_order_status_in_db_first = true
    StraightServer::Order.where(id: @order.id).update(status: 2)
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

      it "doesn't save order if description is too long" do
        expect( -> { create(:order, description: ("text" * 100)) }).to raise_error()
      end

    end

  end

end
