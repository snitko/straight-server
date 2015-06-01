require 'spec_helper'

RSpec.describe StraightServer::Thread do

  it 'labels threads' do
    thread = described_class.new(label: 'payment_id'){}
    expect(thread[:label]).to eq 'payment_id'
  end

  it 'sets and clears interruption flag' do
    thread = described_class.new(label: 'payment_id'){}
    described_class.interrupt(label: 'payment_id')
    expect(described_class.interrupted?(thread: thread)).to eq true
    expect(described_class.interrupted?(thread: thread)).to eq false
  end
end
