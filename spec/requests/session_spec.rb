require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  let(:account) { create(:account) }
  let(:headers) { auth_headers(account) }

  it 'revokes the token on logout' do
    token_headers = headers
    post '/api/v1/logout', headers: token_headers, as: :json
    expect(response).to have_http_status(:ok)

    get '/api/v1/current-user', headers: token_headers
    expect(response).to have_http_status(:unauthorized)
  end

  it 'revokes other sessions when the password changes' do
    other_device = auth_headers(account)
    this_device = auth_headers(account)

    post '/api/v1/change-password', headers: this_device, as: :json,
      params: { password: 'password', 'new-password' => 'new-password-123', 'password-confirm' => 'new-password-123' }
    expect(response).to have_http_status(:ok)
    this_device = { 'Authorization' => response.headers['Authorization'] }

    get '/api/v1/current-user', headers: other_device
    expect(response).to have_http_status(:unauthorized)

    get '/api/v1/current-user', headers: this_device
    expect(response).to have_http_status(:ok)
  end

  describe 'closing the account' do
    let!(:car) { create(:car, account: account) }
    let!(:chat) { create(:chat, account: account, car: car) }

    it 'cancels billing, removes personal data and revokes the token' do
      token_headers = headers
      allow_any_instance_of(AccountClosure).to receive(:cancel_billing!)

      post '/api/v1/close-account', headers: token_headers, params: { password: 'password' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(account.reload).to be_closed
      expect(account.cars).to be_empty
      expect(account.chats).to be_empty

      get '/api/v1/current-user', headers: token_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not close the account when billing cancellation fails' do
      allow_any_instance_of(AccountClosure).to receive(:cancel_billing!).and_raise(StandardError, 'Paddle down')

      post '/api/v1/close-account', headers: headers, params: { password: 'password' }, as: :json

      expect(response).to have_http_status(422)
      expect(account.reload).not_to be_closed
    end
  end
end
