module StraightServer

  class << self
    attr_accessor :db_connection
  end

  class Config

    class << self
      attr_accessor :db, :gateways_source, :gateways
    end

  end

end
