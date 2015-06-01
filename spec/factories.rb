FactoryGirl.define do

  factory :order, class: StraightServer::Order do
    sequence(:id)          { |i| i }
    sequence(:keychain_id) { |i| i }
    sequence(:address)     { |i| "address_#{i}" }
    amount 10
    gateway_id 1
    to_create { |order| order.save }
  end

end
