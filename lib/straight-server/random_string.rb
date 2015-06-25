require 'securerandom'

class String

  def self.random(len)
    BTC::Base58.base58_from_data(SecureRandom.random_bytes(len))[0, len]
  end
end
