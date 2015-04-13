module StraightServer

  class Config

    class << self
      attr_accessor :db, :gateways_source, :gateways, :logmaster, :server_secret, :count_orders, :environment, :redis, :check_order_status_in_db_first
    end

  end

end
