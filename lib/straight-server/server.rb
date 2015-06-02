module StraightServer
  class Server < Goliath::API

    use Goliath::Rack::Params
    include StraightServer::Initializer
    Faye::WebSocket.load_adapter('goliath')

    def initialize
      super
      prepare
      StraightServer.logger.info "starting Straight Server v #{StraightServer::VERSION}"
      require_relative 'order'
      require_relative 'gateway'
      load_addons
      resume_tracking_active_orders!
    end

    def options_parser(opts, options)
      # Even though we define that option here, it is purely for the purposes of compliance with
      # Goliath server. If don't do that, there will be an exception saying "unrecognized argument".
      # In reality, we make use of --config-dir value in the in StraightServer::Initializer and stored
      # it in StraightServer::Initializer.config_dir property.
      opts.on('-c', '--config-dir STRING', "Directory where config files and addons are placed") do |val|
        options[:config_dir] = File.expand_path(val || ENV['HOME'] + '/.straight' )
      end
    end

    def response(env)
      # POST /gateways/1/orders   - create order
      # GET  /gateways/1/orders/1 - see order info
      #      /gateways/1/orders/1/websocket - subscribe to order status changes via a websocket

      # This will be more complicated in the future. For now it
      # just checks that the path starts with /gateways/:id/orders

      StraightServer.logger.watch_exceptions do

        # If the process is daemonized, we get Sequel::DatabaseDisconnectError with Postgres.
        # The explanation is here: https://github.com/thuehlinger/daemons/issues/31
        # Until I figure out where to call connect_to_db so that it connects to the DB
        # AFTER the process is daemonized, this shall remain as it is now.
        begin
          return process_request(env)
        rescue Sequel::DatabaseDisconnectError
          connect_to_db
          return process_request(env)
        end

      end

      # Assume things went wrong, if they didn't go right
      [500, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Server Error"]

    end

    # This is a separate method now because of the need to rescue Sequel::DatabaseDisconnectError
    # As soon as we figure out where should #connect_to_db be placed so that it is executed AFTER the process
    # is daemonized, I'll refactor the code.
    def process_request(env)
      # This is a client implementation example, an html page + a dart script
      # supposed to only be loaded in development.
      if Goliath.env == :development
        if env['REQUEST_PATH'] == '/'
          return [200, {}, IO.read(Initializer::GEM_ROOT + '/examples/client/client.html')]
        elsif Goliath.env == :development && env['REQUEST_PATH'] == '/client.js'
          return [200, {}, IO.read(Initializer::GEM_ROOT + '/examples/client/client.js')]
        end
      end

      @routes.each do |path, action| # path is a regexp
        return action.call(env) if env['REQUEST_PATH'] =~ path
      end
      # no block was called, means no route matched. Let's render 404
      return [404, {}, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} Not found"]
    end

  end
end
