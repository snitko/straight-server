require 'yaml'
require 'json'
require 'sequel'
require 'straight'
require 'logmaster'
require 'openssl'
require 'net/http'
require 'faye/websocket'
Sequel.extension :migration

require_relative 'straight-server/config'
require_relative 'straight-server/initializer'
require_relative 'straight-server/thread'
require_relative 'straight-server/orders_controller'

module StraightServer

  VERSION = Gem.latest_spec_for('straight-server').version.to_s

  class << self
    attr_accessor :db_connection, :logger
  end

end
