require 'yaml'
require 'json'
require 'sequel'
require 'straight'
require 'logmaster'
Sequel.extension :migration

require_relative 'straight-server/config'
require_relative 'straight-server/initializer'
require_relative 'straight-server/orders_controller'

module StraightServer

  class << self
    attr_accessor :db_connection, :logger
  end

end
