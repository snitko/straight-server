Sequel.migration do

  up do
    add_column :gateways, :order_counters, String
  end

  down do
    drop_column :gateways, :order_counters
  end

end
