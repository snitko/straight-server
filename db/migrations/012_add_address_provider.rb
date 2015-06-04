Sequel.migration do

  up do
    add_column :gateways, :address_provider, String, default: "Bip32"
  end

  down do
    drop_column :gateways, :address_provider
  end

end
