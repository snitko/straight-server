Sequel.migration do

  up do
    add_column :gateways, :active, TrueClass, default: true
  end

  down do
    drop_column :gateways, :active
  end

end
