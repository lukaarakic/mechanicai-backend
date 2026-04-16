require 'rails_helper'

RSpec.describe 'Users' do
  let(:account) { create(:account) }
  let(:headers) { auth_headers(account) }

  before do
    allow_any_instance_of(Account).to receive_message_chain(:payment_processor, :subscribed?).and_return(false)
  end

  describe 'GET /api/v1/current-user' do
    it 'returns 401 when unauthenticated' do
      get '/api/v1/current-user'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns current account payload' do
      get '/api/v1/current-user', headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_body).to include('id', 'first_name', 'last_name', 'email', 'avatar', 'onboarding_done', 'subscribed')
    end

    it 'returns subscribed: true when account has active subscription' do
      allow_any_instance_of(Account).to receive_message_chain(:payment_processor, :subscribed?).and_return(true)
      get '/api/v1/current-user', headers: headers
      expect(json_body['subscribed']).to be true
    end
  end

  describe 'PATCH /api/v1/update-user' do
    it 'returns 401 when unauthenticated' do
      patch '/api/v1/update-user', params: { first_name: 'Luka' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'updates first_name and last_name' do
      patch '/api/v1/update-user', headers: headers, params: { first_name: 'Luka', last_name: 'Doe' }
      expect(response).to have_http_status(:ok)
      expect(json_body['first_name']).to eq('Luka')
      expect(json_body['last_name']).to eq('Doe')
    end

    it 'returns 422 when update fails' do
      allow_any_instance_of(Account).to receive(:update).and_return(false)
      patch '/api/v1/update-user', headers: headers, params: { first_name: 'Luka' }
      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Something went wrong')
    end
  end

  describe 'PATCH /api/v1/onboard' do
    let(:valid_params) do
      {
        profile: { first_name: 'Luka', last_name: 'Doe', onboarding_done: true },
        car: { make: 'Toyota', model: 'Corolla', year: 2020, power: 130, size: 2000 }
      }
    end

    it 'returns 401 when unauthenticated' do
      patch '/api/v1/onboard', params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 422 when already onboarded' do
      account.update!(onboarding_done: true)
      patch '/api/v1/onboard', headers: headers, params: valid_params

      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Already onboarded')
    end

    it 'returns 422 when profile params are missing' do
      patch '/api/v1/onboard', headers: headers, params: { car: valid_params[:car] }

      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Profile and car details are required')
    end

    it 'returns 422 when car params are missing' do
      patch '/api/v1/onboard', headers: headers, params: { profile: valid_params[:profile] }

      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Profile and car details are required')
    end

    it 'returns account payload after onboarding' do
      patch '/api/v1/onboard', headers: headers, params: valid_params

      expect(json_body).to include('id', 'first_name', 'onboarding_done', 'subscribed')
      expect(json_body['onboarding_done']).to be true
    end
  end
end
