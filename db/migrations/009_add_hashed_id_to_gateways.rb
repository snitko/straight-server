Sequel.migration do

  up do
    add_column :gateways, :hashed_id, String
    add_index  :gateways, :hashed_id
    if defined?(StraightServer)
      StraightServer.db_connection[:gateways].each do |g|
        g.update(hashed_id: OpenSSL::HMAC.digest('sha256', StraightServer::Config.server_secret, g[:id].to_s).unpack("H*").first)
      end
    end
  end

  down do
    drop_index  :gateways, :hashed_id
    drop_column :gateways, :hashed_id
  end

end
