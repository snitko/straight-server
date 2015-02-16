
RSpec.describe StraightServer::Initializer do

  it "creates config files" do
    1+1
    require 'byebug'; debugger
    1+1
  end

  it "" do
    def connect_to_db

      # symbolize keys for convenience
      db_config = StraightServer::Config.db.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

      db_name = if db_config[:adapter] == 'sqlite'
        ConfigDir.path + "/" + db_config[:name]
        # STRAIGHT_CONFIG_PATH + "/" + db_config[:name] # spec/tmp
      else
        db_config[:name]
      end
      # check connection
      StraightServer.db_connection = Sequel.connect(
        "#{db_config[:adapter]}://"                                                   +
        "#{db_config[:user]}#{(":" if db_config[:user])}"                             +
        "#{db_config[:password]}#{("@" if db_config[:user] || db_config[:password])}" +
        "#{db_config[:host]}#{(":" if db_config[:port])}"                             +
        "#{db_config[:port]}#{("/" if db_config[:host] || db_config[:port])}"         +
        "#{db_name}"
      )
      end

  end

  it "" do

    def create_logger # should return Logger class
      require_relative 'logger'
      StraightServer.logger = StraightServer::Logger.new(
        log_level:       ::Logger.const_get(Config.logmaster['log_level'].upcase),
        file:            ConfigDir.path + '/' + Config.logmaster['file'],
        raise_exception: Config.logmaster['raise_exception'],
        name:            Config.logmaster['name'],
        email_config:    Config.logmaster['email_config']
      )
    end

  end

  it "" do
    def run_migrations
      print "\nPending migrations for the database detected. Migrating..."
      # expect sec migrator to receive run 
      Sequel::Migrator.run(StraightServer.db_connection, GEM_ROOT + '/db/migrations/')
      print "done\n\n"
    end

  end

end