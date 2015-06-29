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

# Actually load the initializer
require_relative '../lib/straight-server'

# This tells initializer where to read the config file from
ENV['HOME'] = File.expand_path(File.dirname(__FILE__))

initializer = Class.new do
  include StraightServer::Initializer
end.new
initializer.prepare
require_relative '../lib/straight-server/gateway'
require_relative '../lib/straight-server/order'

require_relative 'support/custom_matchers'

require "factory_girl"
require_relative "factories"

require 'webmock/rspec'

# class StraightServer::Order
#   alias :save! :save
# end
#
class StraightServer::Thread
  def self.new(label: nil, &block)
    block.call
    {label: label}
  end
end

RSpec.configure do |config|

  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    StraightServer.db_connection = DB #use a memory DB
  end

  config.before(:each) do |spec|
    # puts spec.description
    DB[:orders].delete
    logger_mock = double("logger mock")
    [:debug, :info, :warn, :fatal, :unknown, :blank_lines].each do |e|
      allow(logger_mock).to receive(e)
    end

    allow(logger_mock).to receive(:watch_exceptions).and_yield

    StraightServer.logger = logger_mock
    StraightServer::GatewayOnConfig.class_variable_get(:@@gateways).each do |g|
      g.last_keychain_id = 0
      g.save
    end

    # Clear Gateway's order counters in Redis
    Redis.current.keys("#{StraightServer::Config.redis[:prefix]}*").each do |k|
      Redis.current.del k
    end

  end

  config.after(:all) do
    ["default_last_keychain_id", "second_gateway_last_keychain_id", "default_order_counters.yml"].each do |f|
      FileUtils.rm "#{ENV['HOME']}/.straight/#{f}" if File.exists?("#{ENV['HOME']}/.straight/#{f}")
    end
  end

end
