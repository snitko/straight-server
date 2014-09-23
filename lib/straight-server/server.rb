module StraightServer

  class Server < Goliath::API

    use Goliath::Rack::Params
    include StraightServer::Initializer

    def initialize
      prepare
      require_relative 'order'
      require_relative 'gateway'
      require_relative 'orders_controller'
      super
    end

    def response(env)
      # POST /gateways/1/orders      - create order
      # GET  /gateways/1/orders/1    - see order info
      #      /gateways/1/orders/1/ws - subscribe to order status changes via a websocket

      # This will be more complicated in the future. For now it
      # just checks that the path starts with /gateways/:id/orders

      StraightServer.logger.watch_exceptions do
        if env['REQUEST_PATH'] =~ /\A\/gateways\/.+?\/orders(\/.+)?\Z/
          controller = OrdersController.new(env)
          return controller.response
        else
          return [404, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Not found"]
        end
      end

      # Assume things went wrong, if they didn't go right
      [500, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Server Error"]

    end

  end

end
