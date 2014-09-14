Sequel.migration do
  up do
    create_table(:orders) do
      primary_key :id
      String  :address, null: false
      Integer :status,  null: false, default: 0
      Bignum  :amount,  null: false
    end
  end

  down do
    drop_table(:orders)
  end
end
