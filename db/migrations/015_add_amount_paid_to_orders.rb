Sequel.migration do

  up do
    add_column :orders, :amount_paid, Bignum
  end

  down do
    drop_column :orders, :amount_paid
  end

end
