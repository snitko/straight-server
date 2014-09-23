require 'spec_helper'

RSpec.describe StraightServer::OrdersController do

  before(:each) do
    DB.run("DELETE FROM orders")
    @gateway = gateway = StraightServer::Gateway.find_by_id(2)
    allow(gateway).to receive(:address_for_keychain_id).and_return("address#{gateway.last_keychain_id+1}")
    allow(gateway).to receive(:fetch_transactions_for).with(anything).and_return([])
    allow(gateway).to receive(:send_callback_http_request)
  end

  describe "create action" do

    it "creates an order and renders its attrs in json" do
      send_request "POST", '/gateways/2/orders', amount: 10
      expect(response).to render_json_with(order: { status: 0, amount: 10, address: "address1", tid: nil })
    end

    it "renders 409 error when an order cannot be created due to some validation errors" do
      send_request "POST", '/gateways/2/orders', amount: 0
      expect(response[0]).to eq(409)
      expect(response[2]).to eq("Invalid order: amount is invalid")
    end

  end

  describe "show action" do

  end

  describe "websocket action" do

  end

  def send_request(method, path, params={})
    env = Hashie::Mash.new({ 'REQUEST_METHOD' => method, 'REQUEST_PATH' => path, 'params' => params })
    @controller = StraightServer::OrdersController.new(env)
  end

  def response
    @controller.response
  end

end
