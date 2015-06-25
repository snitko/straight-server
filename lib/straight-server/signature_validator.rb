require 'goliath/constants'
require 'base64'

module StraightServer
  class SignatureValidator
    include Goliath::Constants

    SignatureValidatorError = Class.new(StandardError)
    InvalidNonce            = Class.new(SignatureValidatorError)
    InvalidSignature        = Class.new(SignatureValidatorError)

    attr_reader :gateway, :env

    def initialize(gateway, env)
      @gateway = gateway
      @env     = env
    end

    def validate!
      raise InvalidNonce unless valid_nonce?
      raise InvalidSignature unless valid_signature?
      true
    end

    def valid_nonce?
      nonce = env["#{HTTP_PREFIX}X_NONCE"].to_i
      redis = StraightServer.redis_connection
      loop do
        redis.watch last_nonce_key do
          last_nonce = redis.get(last_nonce_key).to_i
          if last_nonce < nonce
            result = redis.multi do |multi|
              multi.set last_nonce_key, nonce
            end
            return true if result[0] == 'OK'
          else
            redis.unwatch
            return false
          end
        end
      end
    end

    def valid_signature?
      signature == env["#{HTTP_PREFIX}X_SIGNATURE"]
    end

    def last_nonce_key
      "#{Config[:'redis.prefix']}:LastNonce:#{gateway.id}"
    end

    def signature
      self.class.signature(
        nonce:       env["#{HTTP_PREFIX}X_NONCE"],
        body:        env[RACK_INPUT].kind_of?(StringIO) ? env[RACK_INPUT].string : env[RACK_INPUT].to_s,
        method:      env[REQUEST_METHOD],
        request_uri: env[REQUEST_URI],
        secret:      gateway.secret,
      )
    end

    # Should mirror StraightServerKit.signature
    def self.signature(nonce:, body:, method:, request_uri:, secret:)
      sha512  = OpenSSL::Digest::SHA512.new
      request = "#{method.to_s.upcase}#{request_uri}#{sha512.digest("#{nonce}#{body}")}"
      Base64.strict_encode64 OpenSSL::HMAC.digest(sha512, secret.to_s, request)
    end
  end
end
