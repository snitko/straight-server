require 'yaml'
require 'json'
require 'sequel'
require 'straight'
require 'logmaster'
require 'hmac'
require 'hmac-sha1'
require 'net/http'
require 'faye/websocket'
Sequel.extension :migration

require_relative 'straight-server/config'
require_relative 'straight-server/initializer'
require_relative 'straight-server/thread'
require_relative 'straight-server/orders_controller'

module StraightServer

  VERSION = '0.1.0' # TODO: move this to a separate VERSION file which is updated automatically

  class << self
    attr_accessor :db_connection, :logger
  end

end
