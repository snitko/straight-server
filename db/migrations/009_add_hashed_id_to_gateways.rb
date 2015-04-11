Sequel.migration do

  up do
    add_column :gateways, :hashed_id, String
    add_index  :gateways, :hashed_id, unique: true
    StraightServer.db_connection[:gateways].each do |g|
      g.update(hashed_id: OpenSSL::HMAC.digest('sha256', StraightServer::Config.server_secret, g[:id].to_s).unpack("H*").first)
    end
  end

  down do
    remove_index  :gateways, :hashed_id
    remove_column :gateways, :hashed_id
  end

end
