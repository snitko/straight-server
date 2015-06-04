Sequel.migration do

  up do
    add_column :orders, :callback_data, String
  end

  down do
    drop_column :orders, :callback_data
  end

end
