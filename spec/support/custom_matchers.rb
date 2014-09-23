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

RSpec::Matchers.define :render_json_with do |hash|

  match do |r|
    json_response = JSON.parse(r[2])
    check_one_dimensional_hash(hash, json_response)
  end

  def check_one_dimensional_hash(hash, json_response)
    hash.each do |k,v|
      if v == :anything
        expect(json_response[k.to_s]).to_not be_nil
      elsif v == nil
        expect(json_response[k.to_s]).to be_nil
      elsif v.kind_of?(Hash)
        expect(json_response[k.to_s].kind_of?(Hash)).to be_truthy
        check_one_dimensional_hash(v, json_response[k.to_s])
      else
        expect(json_response[k.to_s]).to eq(v)
      end
    end
  end

  failure_message do |actual|
    "expected that it had:\n\n\t\t#{hash},\n\nbut instead it had:\n\n\t\t#{JSON.parse(actual[2])}"
  end
  failure_message_when_negated do |actual|
    "expected that it wouldn't render #{hash.inspect} but it did!"
  end

end
