Sequel.migration do

  up do
    add_column :gateways, :active, TrueClass, default: true
  end

  down do
    remove_column :gateways, :active
  end

end
