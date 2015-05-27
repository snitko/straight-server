Sequel.migration do

  up do
    add_column :gateways, :orders_expiration_period, Integer
  end

  down do
    drop_column :gateways, :orders_expiration_period
  end

end
