Sequel.migration do

  up do
    add_column :gateways, :address_derivation_scheme, String
  end

  down do
    drop_column :gateways, :address_derivation_scheme
  end

end
