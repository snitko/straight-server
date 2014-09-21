Sequel.migration do

  up do
    create_table(:gateways) do
      primary_key :id
      Integer :confirmations_required, null: false, default: 0
      Integer :last_keychain_id,       null: false, default: 0
      String  :pubkey,      null: false
      String  :order_class, null: false
      String  :secret,      null: false
      String  :name,        null: false
    end
  end

  down do
    drop_table(:gateways)
  end

end
