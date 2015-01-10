Sequel.migration do

  up do
    add_column :orders, :description, String
  end

  down do
    remove_column :orders, :description
  end

end
