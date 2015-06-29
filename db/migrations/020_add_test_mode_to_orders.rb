Sequel.migration do

  up do
    add_column :orders, :test_mode, TrueClass, default: false
  end

  down do
    drop_column :orders, :test_mode
  end

end
