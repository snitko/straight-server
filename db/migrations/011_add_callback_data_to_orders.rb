Sequel.migration do

  up do
    add_column :orders, :callback_data, String
  end

  down do
    remove_column :orders, :callback_data
  end

end
