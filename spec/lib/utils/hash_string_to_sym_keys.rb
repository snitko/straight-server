require_relative "../../../lib/straight-server/utils/hash_string_to_sym_keys"

describe Hash do

  it "converts string keys to symbols in a hash" do
    hash = { 'hello' => 'world', 'hello?' => 'world!' }
    hash.keys_to_sym!
    expect(hash).to include(hello: 'world', :hello? => 'world!')
    expect(hash).not_to include('hello' => 'world', 'hello?' => 'world!')
  end
  
  it "doesn't convert string keys that have spaces or other unintended chars in them" do
    hash = { 'hello' => 'world', 'hello hi' => 'world planet' }
    hash.keys_to_sym!
    expect(hash).to include(hello: 'world', 'hello hi' => 'world planet')
  end

end
