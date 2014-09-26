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
        order = @gateway.create_order(amount: @params['amount'])
        StraightServer::Thread.new do
          order.start_periodic_status_check
        end
        [200, {}, order.to_json ]
      rescue Sequel::ValidationFailed => e
        StraightServer.logger.warn "WARNING: validation errors in order, cannot create it."
        [409, {}, "Invalid order: #{e.message}" ]
      end
    end

    def show
      order = Order[@params['id']]
      if order
        order.status(reload: true)
        order.save if order.status_changed?
        [200, {}, order.to_json]
      end
    end

    def websocket
      order = Order[@params['id']]
      if order
        begin
          @gateway.add_websocket_for_order ws = Faye::WebSocket.new(@env), order
          ws
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
          @params['id'] = @request_path[3].to_i
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
