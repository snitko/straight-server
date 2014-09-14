module Straight

  class OrdersController

    attr_reader :response

    def initialize(env)
      @env          = env
      @method       = env['REQUEST_METHOD']
      @request_path = env['REQUEST_PATH'].split('/').delete_if { |s| s.nil? || s.empty? }
    end

    def create
      [200, {}, "order created"]
    end

    def show
      [200, {}, "order info"]
    end

    def order_websocket
      [200, {}, "order websocket"]
    end

    private

      def dispatch
        puts "dispatching..."
        @response = if @request_path[3] # if an order id is supplied
          if @request_path[4] == 'ws'
            order_websocket
          elsif @request_path[4].nil? && @method == 'GET'
            show
          end
        elsif @request_path[3].nil? && @method == 'POST'
          create
        end
        @response = [404, {}, "#{@method} /#{@request_path.join('/')} Not found"] if @response.nil? 
      end

  end

end
