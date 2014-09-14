module Straight

  class Server < Goliath::API

    use Goliath::Rack::Params

    def initialize
      super
    end

    def response(env)
      # POST /gateways/1/orders      - create order
      # GET  /gateways/1/orders/1    - see order info
      #      /gateways/1/orders/1/ws - subscribe to order status changes via a websocket

      # This will be more complicated in the future. For now it
      # just checks that the path starts with /gateways/:id/orders
      if env['REQUEST_PATH'] =~ /\A\/gateways\/.+?\/orders(\/.+)?\Z/
        controller = OrdersController.new(env)
        controller.response
      else
        [404, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Not found"]
      end

    end

  end

end
