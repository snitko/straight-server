Sequel.migration do

  up do
    add_column :orders, :description, String
  end

  down do
    drop_column :orders, :description
  end

end
