module StraightServer

  class Config

    class << self
      attr_accessor :db, :gateways_source, :gateways, :logmaster, :server_secret
    end

  end

end
