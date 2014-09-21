Sequel.migration do

  up do
    create_table(:orders) do
      primary_key :id
      String  :address,     null: false
      Integer :status,      null: false, default: 0
      Integer :keychain_id, null: false
      Bignum  :amount,      null: false
      Integer :gateway_id,  null: false
    end
    add_index :orders, :id,      unique: true
    add_index :orders, :address, unique: true
    add_index :orders, [:keychain_id, :gateway_id], unique: true
  end

  down do
    drop_table(:orders)
  end

end
