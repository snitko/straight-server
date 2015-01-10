Sequel.migration do

  up do
    add_column :orders, :payment_id, String
    add_index :orders, :payment_id, unique: true
  end

  down do
    drop_index    :orders, :payment_id
    remove_column :orders, :payment_id
  end

end
