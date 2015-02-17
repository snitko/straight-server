# !!! The order in which we require files here is very important.

# 1. First, load dependencies and connect to the Database
require 'sequel'
require 'straight'
require 'fileutils' # This is required to cleanup the test .straight dir
require 'hashie'

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
require_relative "../lib/straight-server/utils/hash_string_to_sym_keys"
include StraightServer::Initializer
StraightServer::Initializer::ConfigDir.set!
read_config_file

# 4. Load the rest of the files, including models, which are now ready
# to be used as intended and will follow all the previous configuration.
require_relative '../lib/straight-server/order'
require_relative '../lib/straight-server/gateway'
require_relative '../lib/straight-server/orders_controller'
require_relative '../lib/straight-server'

require_relative 'support/custom_matchers'

require "factory_girl"
require_relative "factories"

class StraightServer::Order
  alias :save! :save
end

class StraightServer::Thread
  def self.new(&block)
    block.call
  end
end

RSpec.configure do |config|

  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    StraightServer.db_connection = DB #use a memory DB
  end

  config.before(:each) do
    DB[:orders].delete
    logger_mock = double("logger mock")
    [:debug, :info, :warn, :fatal, :unknown, :blank_lines].each do |e|
      allow(logger_mock).to receive(e)
    end
    StraightServer.logger = logger_mock
    StraightServer::GatewayOnConfig.class_variable_get(:@@gateways).each do |g|
      g.last_keychain_id = 0
      g.save
    end
    ["default_order_counters.yml", "second_gateway_order_counters.yml"].each do |f|
      FileUtils.rm "#{ENV['HOME']}/.straight/#{f}" if File.exists?("#{ENV['HOME']}/.straight/#{f}")
    end
  end

  config.after(:all) do
    ["default_last_keychain_id", "second_gateway_last_keychain_id", "default_order_counters.yml"].each do |f|
      FileUtils.rm "#{ENV['HOME']}/.straight/#{f}" if File.exists?("#{ENV['HOME']}/.straight/#{f}")
    end
  end

end
