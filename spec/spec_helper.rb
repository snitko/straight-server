require 'sequel'
require 'straight'
Sequel.extension :migration
DB = Sequel.sqlite

Sequel::Migrator.run(DB, File.expand_path('../', File.dirname(__FILE__)) + '/db/migrations/')

require_relative "../lib/straight-server"
require_relative "support/custom_matchers"

RSpec.configure do |config|

  config.before(:suite) do
    StraightServer.db_connection = DB #use a memory DB
  end

end
