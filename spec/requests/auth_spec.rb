require 'rails_helper'

RSpec.describe 'Auth' do
  describe 'POST /api/v1/login', type: :request do
    let!(:account) { create(:account) }

    context 'with valid credentials' do
      it 'returns a JWT token' do
        post '/api/v1/login', params: { email: account.email, password: 'password' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.headers['Authorization']).to be_present
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized' do
        post '/api/v1/login', params: { email: account.email, password: 'wrong' }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/register', type: :request do
    context 'with valid params' do
      it 'creates a user' do
        post '/api/v1/register', params: {
          email: 'new@example.com',
          password: 'password',
          'password-confirm': 'password'
        }, as: :json

        expect(response).to have_http_status(200)
      end
    end

    context 'with mismatched passwords' do
      it 'returns an error' do
        post '/api/v1/register', params: {
          email: 'new@example.com',
          password: 'password',
          'password-confirm': 'wrong'
        }, as: :json

        expect(response).to have_http_status(422)
      end
    end
  end
end