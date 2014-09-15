module StraightServer

  module Initializer

    GEM_ROOT             = File.expand_path('../..', File.dirname(__FILE__))
    STRAIGHT_CONFIG_PATH = ENV['HOME'] + '/.straight'

    def prepare
      create_config_file unless File.exist?(STRAIGHT_CONFIG_PATH + '/config.yml')
      read_config_file
      connect_to_db
      run_migrations if migrations_pending?
    end

    private

      def create_config_file
        puts "\e[1;33mWARNING!\e[0m \e[33mNo file ~/.straight/config was found. Created a sample one for you.\e[0m"
        puts "You should edit it and try starting the server again.\n"

        FileUtils.mkdir_p(STRAIGHT_CONFIG_PATH) unless File.exist?(STRAIGHT_CONFIG_PATH)
        FileUtils.cp(GEM_ROOT + '/templates/config.yml', ENV['HOME'] + '/.straight/') 
        puts "Shutting down now.\n\n"
        exit
      end

      def read_config_file
        YAML.load_file(ENV['HOME'] + '/.straight/config.yml').each do |k,v|
          StraightServer::Config.send(k + '=', v)
        end
      end

      def connect_to_db

        # symbolize keys for convenience
        db_config = StraightServer::Config.db.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

        db_name = if db_config[:adapter] == 'sqlite'
          STRAIGHT_CONFIG_PATH + "/" + db_config[:name]
        else
          db_config[:name]
        end

        StraightServer.db_connection = Sequel.connect(
          "#{db_config[:adapter]}://"                                                   +
          "#{db_config[:user]}#{(":" if db_config[:user])}"                             +
          "#{db_config[:password]}#{("@" if db_config[:user] || db_config[:password])}" +
          "#{db_config[:host]}#{(":" if db_config[:port])}"                             +
          "#{db_config[:port]}#{("/" if db_config[:host] || db_config[:port])}"         +
          "#{db_name}"
        )
      end

      def run_migrations
        print "\nPending migrations for the database detected. Migrating..."
        Sequel::Migrator.run(StraightServer.db_connection, GEM_ROOT + '/db/migrations/')
        print "done\n\n"
      end

      def migrations_pending?
        !Sequel::Migrator.is_current?(StraightServer.db_connection, GEM_ROOT + '/db/migrations/')
      end

  end

end
