Sequel.migration do
  change do
    alter_table :gateways do
      set_column_allow_null :pubkey
      set_column_not_null   :address_provider
    end
  end
end
