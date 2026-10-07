require 'rails_helper'

RSpec.describe Rack::Attack do
  def request_with(headers)
    Rack::Request.new(Rack::MockRequest.env_for('/api/v1/login', { 'REMOTE_ADDR' => '10.0.0.1' }.merge(headers)))
  end

  before { stub_const('Rack::Attack::INTERNAL_SECRET', 'shared-secret') }

  it 'trusts X-Client-IP when the internal secret matches' do
    request = request_with('HTTP_X_CLIENT_IP' => '203.0.113.7', 'HTTP_X_INTERNAL_SECRET' => 'shared-secret')
    expect(described_class.client_ip(request)).to eq('203.0.113.7')
  end

  it 'ignores X-Client-IP without the internal secret' do
    request = request_with('HTTP_X_CLIENT_IP' => '203.0.113.7', 'HTTP_X_INTERNAL_SECRET' => 'wrong')
    expect(described_class.client_ip(request)).to eq('10.0.0.1')
  end

  it 'keys authenticated requests by account' do
    token = JWT.encode({ 'account_id' => 'abc' }, ENV.fetch('JWT_SECRET'), 'HS256')
    request = request_with('HTTP_AUTHORIZATION' => token)
    expect(described_class.account_or_ip(request)).to eq('account:abc')
  end

  it 'falls back to the client IP for forged tokens' do
    token = JWT.encode({ 'account_id' => 'abc' }, 'not-the-secret', 'HS256')
    request = request_with('HTTP_AUTHORIZATION' => token)
    expect(described_class.account_or_ip(request)).to eq('ip:10.0.0.1')
  end
end
