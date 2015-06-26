Sequel.migration do

  up do
    add_column :gateways, :test_last_keychain_id, Integer, default: 0, null: false
  end

  down do
    drop_column :gateways, :test_last_keychain_id
  end

end
