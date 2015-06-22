Sequel.migration do

  up do
    add_column :orders, :amount_paid, :bignum
  end

  down do
    drop_column :orders, :amount_paid
  end

end
