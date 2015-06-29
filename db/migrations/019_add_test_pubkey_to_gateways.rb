Sequel.migration do

  up do
    add_column :gateways, :test_pubkey, String
  end

  down do
    drop_column :gateways, :test_pubkey
  end

end
