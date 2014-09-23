require 'yaml'
require 'json'
require 'sequel'
require 'straight'
Sequel.extension :migration

require_relative 'straight-server/config'
require_relative 'straight-server/initializer'
require_relative 'straight-server/orders_controller'

module StraightServer

  class << self
    attr_accessor :db_connection
  end

end
