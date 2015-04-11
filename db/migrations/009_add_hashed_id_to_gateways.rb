Sequel.migration do

  up do
    add_column :gateways, :hashed_id, String
    add_index  :gateways, :hashed_id, unique: true
  end

  down do
    remove_index  :gateways, :hashed_id
    remove_column :gateways, :hashed_id
  end

end
