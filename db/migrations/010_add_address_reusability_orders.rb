Sequel.migration do

  up do
    drop_index  :orders, [:keychain_id, :gateway_id]
    drop_index  :orders, :address
    add_index :orders, [:keychain_id, :gateway_id]
    add_index :orders, :address
    add_column :orders, :reused, Integer, default: 0
  end

  down do
    drop_index  :orders, [:keychain_id, :gateway_id]
    drop_index  :orders, :address
    drop_column :orders, :reused 
    add_index :orders, [:keychain_id, :gateway_id], unique: true
    add_index :orders, :address, unique: true
  end

end
