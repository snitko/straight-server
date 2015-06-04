Sequel.migration do
  change do
    create_table(:gateways, :ignore_index_errors=>true) do
      primary_key :id
      Integer :confirmations_required, :default=>0, :null=>false
      Integer :last_keychain_id, :default=>0, :null=>false
      String :pubkey, :size=>255, :null=>false
      String :order_class, :size=>255, :null=>false
      String :secret, :size=>255, :null=>false
      String :name, :size=>255, :null=>false
      String :default_currency, :default=>"BTC", :size=>255
      String :callback_url, :size=>255
      TrueClass :check_signature, :default=>false, :null=>false
      String :exchange_rate_adapter_names, :size=>255
      DateTime :created_at, :null=>false
      DateTime :updated_at
      Integer :orders_expiration_period
      TrueClass :check_order_status_in_db_first
      TrueClass :active, :default=>true
      String :order_counters, :size=>255
      String :hashed_id, :size=>255
      String :address_provider, :default=>"Bip32", :size=>255
      String :address_derivation_scheme, :size=>255
      
      index [:hashed_id]
      index [:id], :unique=>true
      index [:name], :unique=>true
      index [:pubkey], :unique=>true
    end
    
    create_table(:orders, :ignore_index_errors=>true) do
      primary_key :id
      String :address, :size=>255, :null=>false
      String :tid, :size=>255
      Integer :status, :default=>0, :null=>false
      Integer :keychain_id, :null=>false
      Bignum :amount, :null=>false
      Integer :gateway_id, :null=>false
      String :data, :size=>255
      String :callback_response, :text=>true
      DateTime :created_at, :null=>false
      DateTime :updated_at
      String :payment_id, :size=>255
      String :description, :size=>255
      Integer :reused, :default=>0
      String :callback_data, :size=>255
      
      index [:address]
      index [:id], :unique=>true
      index [:keychain_id, :gateway_id]
      index [:payment_id], :unique=>true
    end
    
    create_table(:schema_info) do
      Integer :version, :default=>0, :null=>false
    end
  end
end
