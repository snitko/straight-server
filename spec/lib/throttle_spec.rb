require 'spec_helper'
require 'timecop'

RSpec.describe StraightServer::Throttler do

  it 'throttles requests' do
    new_config          = StraightServer::Config.clone
    new_config.throttle = {requests_limit: 1, period: 1}
    stub_const 'StraightServer::Config', new_config
    throttler1 = described_class.new(1)
    throttler2 = described_class.new(2)
    now        = Time.now.round
    Timecop.freeze(now) do
      expect(throttler1.deny?('127.0.0.1')).to eq false
      expect(throttler1.deny?('127.0.0.1')).to eq true
      expect(throttler2.deny?('127.0.0.1')).to eq false # does not affect other gateways
    end
    Timecop.freeze(now + 0.5) do
      expect(throttler1.deny?('127.0.0.2')).to eq false
    end
    Timecop.freeze(now + 1.1) do
      expect(throttler1.deny?('127.0.0.2')).to eq false # new timeframe
      expect(throttler1.deny?('127.0.0.2')).to eq true
      expect(throttler2.deny?('127.0.0.2')).to eq false
      expect(throttler1.deny?('127.0.0.1')).to eq false
      expect(throttler1.deny?('127.0.0.1')).to eq true
      expect(throttler2.deny?('127.0.0.1')).to eq false
    end
  end

  it 'bans by ip' do
    new_config          = StraightServer::Config.clone
    new_config.throttle = {requests_limit: 3, period: 1, ip_ban_duration: 30}
    stub_const 'StraightServer::Config', new_config
    throttler1 = described_class.new(1)
    throttler2 = described_class.new(2)
    3.times { expect(throttler1.deny?('127.0.0.1')).to eq false }
    banned_at = Time.now
    [0, 10, 20, 30].each do |offset|
      Timecop.freeze(banned_at + offset) do
        expect(throttler1.deny?('127.0.0.1')).to eq true
        expect(throttler2.deny?('127.0.0.1')).to eq true # affects any gateways
        expect(throttler1.deny?('127.0.0.2')).to eq false
        expect(throttler2.deny?('127.0.0.2')).to eq false
      end
    end
    Timecop.freeze(banned_at + 31) do
      expect(throttler1.deny?('127.0.0.1')).to eq false
      expect(throttler2.deny?('127.0.0.1')).to eq false
    end
  end
end
