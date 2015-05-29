require 'yaml'
require 'json'
require 'sequel'
require 'straight'
require 'logmaster'
require 'openssl'
require 'base64'
require 'net/http'
require 'redis'
require 'faye/websocket'
Sequel.extension :migration


require_relative 'straight-server/utils/hash_string_to_sym_keys'
require_relative 'straight-server/random_string'
require_relative 'straight-server/config'
require_relative 'straight-server/initializer'
require_relative 'straight-server/thread'
require_relative 'straight-server/orders_controller'

module StraightServer

  VERSION = File.read(File.expand_path('../', File.dirname(__FILE__)) + '/VERSION')

  class << self
    attr_accessor :db_connection, :logger
  end

end
