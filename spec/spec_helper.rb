require_relative "../lib/straight-server"
require_relative "support/custom_matchers"

RSpec.configure do |config|


  config.before(:suite) do
    StraightServer.db_connection = Sequel.sqlite # use a memory DB
    Sequel::Migrator.run(StraightServer.db_connection, StraightServer::Initializer::GEM_ROOT + '/db/migrations/')
    DB = StraightServer.db_connection
  end

end
