RSpec::Matchers.define :equal_order do |expected|
  match do |actual|
    true
    actual.address == expected.address         &&
    actual.status  == expected.status          &&
    actual.keychain_id == expected.keychain_id &&
    actual.amount      == expected.amount      &&
    actual.gateway_id  == expected.gateway_id  &&
    actual.id          == expected.id
  end

  diffable
end
