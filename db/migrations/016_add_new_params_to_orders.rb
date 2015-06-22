Sequel.migration do

  up do
    add_column :orders, :callback_url, String
    add_column :orders, :title, String
  end

  down do
    drop_column :orders, :callback_url
    drop_column :orders, :title
  end

end
