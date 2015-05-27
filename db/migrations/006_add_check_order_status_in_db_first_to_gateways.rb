Sequel.migration do

  up do
    add_column :gateways, :check_order_status_in_db_first, TrueClass
  end

  down do
    drop_column :gateways, :check_order_status_in_db_first
  end

end
