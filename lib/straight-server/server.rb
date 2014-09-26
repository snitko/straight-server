module StraightServer
  class Server < Goliath::API

    use Goliath::Rack::Params
    include StraightServer::Initializer
    Faye::WebSocket.load_adapter('goliath')

    def initialize
      prepare
      require_relative 'order'
      require_relative 'gateway'
      require_relative 'orders_controller'
      super
    end

    def response(env)
      # POST /gateways/1/orders   - create order
      # GET  /gateways/1/orders/1 - see order info
      #      /gateways/1/orders/1/websocket - subscribe to order status changes via a websocket

      # This will be more complicated in the future. For now it
      # just checks that the path starts with /gateways/:id/orders

      StraightServer.logger.watch_exceptions do

        # This is a client implementation example, an html page + a dart script
        # supposed to only be loaded in development.
        if Goliath.env == :development
          if env['REQUEST_PATH'] == '/'
            return [200, {}, IO.read(Initializer::GEM_ROOT + '/examples/client/client.html')]
          elsif Goliath.env == :development && env['REQUEST_PATH'] == '/client.dart'
            return [200, {}, IO.read(Initializer::GEM_ROOT + '/examples/client/client.dart')]
          end
        end

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
