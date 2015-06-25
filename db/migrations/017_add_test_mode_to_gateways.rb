Sequel.migration do

  up do
    add_column :gateways, :test_mode, TrueClass, default: false
  end

  down do
    drop_column :gateways, :test_mode
  end

end
