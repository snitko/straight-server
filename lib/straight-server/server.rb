module Straight

  class Server < Goliath::API

    use Goliath::Rack::Params

    def initialize
      super
    end

    def response(env)
    end

  end

end
