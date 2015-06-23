require_relative 'throttler'

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

      unless @gateway
        StraightServer.logger.warn "Gateway not found"
        return [404, {}, "Gateway not found" ]
      end

      unless @gateway.check_signature
        ip = @env['HTTP_X_FORWARDED_FOR'].to_s
        ip = @env['REMOTE_ADDR'] if ip.empty?
        if StraightServer::Throttler.new(@gateway.id).deny?(ip)
          StraightServer.logger.warn message = "Too many requests, please try again later"
          return [429, {}, message]
        end
      end

      begin

        # This is to inform users of previous version of a deprecated param
        # It will have to be removed at some point.
        if @params['order_id']
          return [409, {}, "Error: order_id is no longer a valid param. Use keychain_id instead and consult the documentation." ]
        end

        order_data = {
          amount:           @params['amount'], # this is satoshi
          currency:         @params['currency'],
          btc_denomination: @params['btc_denomination'],
          keychain_id:      @params['keychain_id'],
          signature:        @params['signature'],
          callback_data:    @params['callback_data'],
          data:             @params['data'],
          description:      @params['description']
        }
        order = @gateway.create_order(order_data)
        StraightServer::Thread.new(label: order.payment_id) do
          # Because this is a new thread, we have to wrap the code inside in #watch_exceptions
          # once again. Otherwise, no watching is done. Oh, threads!
          StraightServer.logger.watch_exceptions do
            order.start_periodic_status_check
          end
        end
        [200, {}, add_callback_data_warning(order).to_json]
      rescue Sequel::ValidationFailed => e
        StraightServer.logger.warn(
          "VALIDATION ERRORS in order, cannot create it:\n" +
          "#{e.message.split(",").each_with_index.map { |e,i| "#{i+1}. #{e.lstrip}"}.join("\n") }\n" +
          "Order data: #{order_data.inspect}\n"
        )
        [409, {}, "Invalid order: #{e.message}" ]
      rescue Straight::Gateway::OrderAmountInvalid => e
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

      unless @gateway
        StraightServer.logger.warn "Gateway not found"
        return [404, {}, "Gateway not found" ]
      end

      order = find_order

      if order
        order.status(reload: true)
        order.save if order.status_changed?
        [200, {}, order.to_json]
      end
    end

    def websocket

      order = find_order
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

    def cancel
      unless @gateway
        StraightServer.logger.warn "Gateway not found"
        return [404, {}, "Gateway not found"]
      end
      if (order = find_order)
        if @gateway.check_signature
          signature = @gateway.sign_with_secret(order.keychain_id, level: 2)
          if @params['signature'] != signature
            return [409, {}, "Invalid signature"]
          end
        end
        order.status(reload: true)
        order.save if order.status_changed?
        if order.cancelable?
          order.cancel
          [200, {}, '']
        else
          [409, {}, "Order is not cancelable"]
        end
      end
    end

    def last_keychain_id
      unless @gateway
        StraightServer.logger.warn "Gateway not foun"
        return [404, {}, "Gateway not found"]
      end

      [200, {}, {gateway_id: @gateway.id, last_keychain_id: @gateway.last_keychain_id}.to_json]
    end

    private

      # Refactoring proposed: https://github.com/AlexanderPavlenko/straight-server/commit/49ea6e3732a9564c04d8dfecaee6d0ebaa462042
      def dispatch

        StraightServer.logger.blank_lines
        StraightServer.logger.info "#{@method} #{@env['REQUEST_PATH']}\n#{@params}"

        @gateway = StraightServer::Gateway.find_by_hashed_id(@request_path[1])

        @response = if @request_path[3] # if an order id is supplied
          @params['id'] = @request_path[3]
          @params['id'] = @params['id'].to_i if @params['id'] =~ /\A\d+\Z/
          if @request_path[4] == 'websocket'
            websocket
          elsif @request_path[4] == 'cancel'&& @method == 'POST'
            cancel
          elsif @request_path[4].nil? && @method == 'GET'
            show
          end
        elsif @request_path[2] == 'last_keychain_id'
            last_keychain_id
        elsif @request_path[3].nil?# && @method == 'POST'
          create
        end
        @response = [404, {}, "#{@method} /#{@request_path.join('/')} Not found"] if @response.nil?
      end

      def find_order
        if @params['id'] =~ /[^\d]+/
          Order[:payment_id => @params['id']]
        else
          Order[@params['id']]
        end
      end

      def add_callback_data_warning(order)
        o = order.to_h
        if @params['data'].kind_of?(String) && @params['callback_data'].nil?
          o[:WARNING] = "Maybe you meant to use callback_data? The API has changed now. Consult the documentation."
        end
        o
      end

  end

end
