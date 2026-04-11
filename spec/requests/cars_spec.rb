require 'rails_helper'

RSpec.describe 'Cars API', type: :request do
  let!(:account) { create(:account) }
  let!(:headers) { auth_headers(account) }
  let!(:car) { create(:car, account: account) }

  it 'returns the user\'s cars' do
    puts "Account id: #{account.id}"
    puts "Account email: #{account.email}"
    puts "Account persisted: #{account.persisted?}"
  end

  describe 'GET /api/v1/cars' do
    it 'returns the users\'s cars' do
      get '/api/v1/cars', headers:headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

end