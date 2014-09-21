# !!! The order in which we require files here is very important.

# 1. First, load dependencies and connect to the Database
require 'sequel'
require 'straight'
Sequel.extension :migration
DB = Sequel.sqlite

# 2. Then we can run migrations BEFORE we load actual models
Sequel::Migrator.run(DB, File.expand_path('../', File.dirname(__FILE__)) + '/db/migrations/')

# 3. Load config and initializer so that we can read our test config file located in
# spec/.straight/config.yml

# 3.1 This tells initializer where to read the config file from
ENV['HOME'] = File.expand_path(File.dirname(__FILE__))

# 3.2 Actually load the initializer
require_relative "../lib/straight-server/config"
require_relative "../lib/straight-server/initializer"
include StraightServer::Initializer

# This is required to cleanup the test .straight dir
require 'fileutils'

read_config_file

# 4. Load the rest of the files, including models, which are now ready
# to be used as intended and will follow all the previous configuration.
require_relative "../lib/straight-server"
require_relative "support/custom_matchers"

RSpec.configure do |config|

  config.before(:suite) do
    StraightServer.db_connection = DB #use a memory DB
  end

  config.before(:each) do
    StraightServer::GatewayOnConfig.class_variable_get(:@@gateways).each do |g|
      g.last_keychain_id = 0
      g.save
    end
  end

  config.after(:all) do
    ["default_last_keychain_id", "second_gateway_last_keychain_id"].each do |f|
      FileUtils.rm "#{ENV['HOME']}/.straight/#{f}" if File.exists?("#{ENV['HOME']}/.straight/#{f}")
    end
  end

end
