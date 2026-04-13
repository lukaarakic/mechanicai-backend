require 'rails_helper'

RSpec.describe 'Cars API', type: :request do
  let!(:account) { create(:account) }
  let!(:headers) { auth_headers(account) }
  let(:car) { create(:car, account: account) }

  describe 'GET /api/v1/cars' do
    it 'returns 200 and list of cars' do
      create_list(:car, 3, account: account)
      get '/api/v1/cars', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(3)
    end

    it "returns 401 when unauthenticated" do
      get "/api/v1/cars"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/cars/:id' do
    it "returns the correct car" do
      get "/api/v1/cars/#{car.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body["make"]).to eq(car.make)
    end

    it "returns 404 for a car that doesn't belog to the account" do
      other_car = create(:car)
      get "/api/v1/cars/#{other_car.id}", headers: headers

      expect(response).to have_http_status(:not_found)

    end
  end

  describe "POST /api/v1/cars" do
    let(:valid_params) do
      { car: { make: "Toyota", model: "Corolla", year: 2020, power: 110, size: 2000 } }
    end

    context "when subscribed" do
      before { allow_any_instance_of(ApplicationController).to receive(:is_subscribed).and_return(true) }

      it 'creates a car and returns 201' do
        expect {
          post '/api/v1/cars', params: valid_params, headers: headers
        }.to change(Car, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'assigns car to the current user' do
        post '/api/v1/cars', params: valid_params, headers: headers

        expect(json_body["account_id"]).to eq(account.id)
      end

      it 'returns 422 with invalid params' do
        post '/api/v1/cars', headers: headers, params: { car: { make: nil } }

        expect(response).to have_http_status(422)
      end
    end

    context 'when not subscribed' do
      before { allow_any_instance_of(ApplicationController).to receive(:is_subscribed).and_return(false) }

      it 'can add their first car' do
        expect {
          post '/api/v1/cars', params: valid_params, headers: headers
        }.to change(Car, :count).by(1)
      end

      it "can't add a second car" do
        car
        expect {
          post '/api/v1/cars', params: valid_params, headers: headers
        }.not_to change(Car, :count)

        expect(response).to have_http_status(422)
        expect(json_body['error']).to eq('Upgrade to Pro plan to add more cars')
      end
    end
  end

  describe "PATCH /api/v1/cars/:id" do
    let(:update_params) do
      { car: { make: "Honda" } }
    end

    context 'not authorized' do
      it "can't update a car" do
        patch "/api/v1/cars/#{car.id}", params: update_params

        expect(response).to have_http_status(:unauthorized)
        expect(car.reload.make).not_to eq("Honda")
      end
    end

    context 'authorized' do
      it 'can update a car' do
        patch "/api/v1/cars/#{car.id}", params: update_params, headers: headers

        expect(response).to have_http_status(:ok)
        expect(car.reload.make).to eq("Honda")
      end

      it 'returns 422 with invalid params' do
        patch "/api/v1/cars/#{car.id}", params: { car: { make: nil } }, headers: headers

        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'DELETE /api/v1/cars/:id' do
    context 'not authorized' do
      it "can't delete a car" do
        delete "/api/v1/cars/#{car.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'authorized' do
      it 'can delete a car' do
        car
        expect {
          delete "/api/v1/cars/#{car.id}", headers: headers
        }.to change(Car, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'return 404 for a car not belonging to the account' do
        other_car = create(:car)
        delete "/api/v1/cars/#{other_car.id}", headers: headers

        expect(response).to have_http_status(404)

      end
    end
  end
end
