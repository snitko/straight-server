module StraightServer

  class OrdersController

    attr_reader :response

    def initialize(env)
      @env          = env
      @params       = env.params
      @method       = env['REQUEST_METHOD']
      @request_path = env['REQUEST_PATH'].split('/').delete_if { |s| s.nil? || s.empty? }
      dispatch
    end

    def create
      begin
        order = @gateway.create_order(
          amount:           @params['amount'], # this is satoshi
          currency:         @params['currency'],
          btc_denomination: @params['btc_denomination'],
          id:               @params['order_id'],
          signature:        @params['signature'],
          data:             @params['data']
        )
        StraightServer::Thread.new do
          order.start_periodic_status_check
        end
        [200, {}, order.to_json ]
      rescue Sequel::ValidationFailed => e
        StraightServer.logger.warn "validation errors in order, cannot create it."
        [409, {}, "Invalid order: #{e.message}" ]
      rescue StraightServer::GatewayModule::InvalidSignature
        [409, {}, "Invalid signature for id: #{@params['order_id']}" ]
      rescue StraightServer::GatewayModule::InvalidOrderId
        StraightServer.logger.warn message = "An invalid id for order supplied: #{@params['order_id']}"
        [409, {}, message ]
      rescue StraightServer::GatewayModule::GatewayInactive
        StraightServer.logger.warn message = "The gateway is inactive, you cannot create order with it"
        [503, {}, message ]
      end
    end

    def show
      order = Order[@params['id']] || (@params['id'] =~ /[^\d]+/ && Order[:payment_id => @params['id']])
      if order
        order.status(reload: true)
        order.save if order.status_changed?
        [200, {}, order.to_json]
      end
    end

    def websocket
      order = Order[@params['id']] || (@params['id'] =~ /[^\d]+/ && Order[:payment_id => @params['id']])
      if order
        begin
          @gateway.add_websocket_for_order ws = Faye::WebSocket.new(@env), order
          ws.rack_response
        rescue Gateway::WebsocketExists
          [403, {}, "Someone is already listening to that order"]
        rescue Gateway::WebsocketForCompletedOrder
          [403, {}, "You cannot listen to this order because it is completed (status > 1)"]
        end
      end
    end

    private

      def dispatch
        
        StraightServer.logger.blank_lines
        StraightServer.logger.info "#{@method} #{@env['REQUEST_PATH']}\n#{@params}"

        @gateway = StraightServer::Gateway.find_by_id(@request_path[1])

        @response = if @request_path[3] # if an order id is supplied
          @params['id'] = @request_path[3]
          @params['id'] = @params['id'].to_i if @params['id'] =~ /\A\d+\Z/
          if @request_path[4] == 'websocket'
            websocket
          elsif @request_path[4].nil? && @method == 'GET'
            show
          end
        elsif @request_path[3].nil?# && @method == 'POST'
          create
        end
        @response = [404, {}, "#{@method} /#{@request_path.join('/')} Not found"] if @response.nil? 
      end

  end

end
