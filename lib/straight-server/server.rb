module StraightServer
  class Server < Goliath::API

    use Goliath::Rack::Params
    include StraightServer::Initializer
    Faye::WebSocket.load_adapter('goliath')

    def initialize
      prepare
      StraightServer.logger.info "Starting Straight server v #{StraightServer::VERSION}"
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

        @routes.each do |path, action| # path is a regexp
          return action.call(env) if env['REQUEST_PATH'] =~ path
        end
        # no block was called, means no route matched. Let's render 404
        return [404, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Not found"]

      end

      # Assume things went wrong, if they didn't go right
      [500, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Server Error"]

    end
    
  end
end
