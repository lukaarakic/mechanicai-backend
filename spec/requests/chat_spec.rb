require "rails_helper"

RSpec.describe 'Chat' do
  let(:account) { create(:account) }
  let(:car) { create(:car, account: account) }
  let(:chat) { create(:chat, account: account, car: car) }
  let(:headers) { auth_headers(account) }

  before do
    service_double = double('DiagnosticMessageService')
    allow(DiagnosticMessageService).to receive(:new).and_return(service_double)
    allow(service_double).to receive(:call)
  end


  describe 'POST /api/v1/chats' do
    let(:valid_params) do
      { chat: { car_id: car.id, message: "My car makes a grinding noise when braking" } }
    end


    it 'creates chat with valid params and header' do
      post '/api/v1/chats', headers: headers, params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'returns error when unauthenticated' do
      post '/api/v1/chats', params: valid_params
      expect(response).to have_http_status(401)
    end

    it 'returns 404 when car not found' do
      post '/api/v1/chats', headers: headers, params: { chat: { car_id: 'wrong', message: 'my break squeaks' } }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 when message is blank' do
      post '/api/v1/chats', headers: headers, params: { chat: { car_id: car.id, message: nil } }
      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Message content is required')
    end

    it 'returns 422 when message is too long' do
      post '/api/v1/chats', headers: headers, params: { chat: { car_id: car.id, message: "a"*4001 } }
      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Message content is too long')
    end

    context 'when not subscribed' do
      before { allow_any_instance_of(ApplicationController).to receive(:is_subscribed).and_return(false) }

      it 'can create a chat under monthly limit' do
        post '/api/v1/chats', headers: headers, params: valid_params

        expect(response).to have_http_status(:created)
      end

      it 'is blocked after 3 chats this month' do
        create_list(:chat, 3, account: account, car: car)

        post '/api/v1/chats', headers: headers, params: valid_params

        expect(response).to have_http_status(:forbidden)
        expect(json_body['error']).to eq("You've reached your free limit of 3 chats per month.")
      end
    end

    context 'when subscribed' do
      before { allow_any_instance_of(ApplicationController).to receive(:is_subscribed).and_return(true) }

      it 'is create more then 3 chats in a month' do
        create_list(:chat, 3, account: account, car: car)
        post '/api/v1/chats', headers: headers, params: valid_params

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'GET /api/v1/chats' do
    it 'returns 401 when unauthenticated' do
      get '/api/v1/chats'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns all chats when authenticated' do
      get '/api/v1/chats', headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'returns chats with default limit of 10' do
      create_list(:chat, 15, account: account, car: car)
      get '/api/v1/chats', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.size).to eq(10)
    end

    it 'respects the limit param' do
      create_list(:chat, 10, account: account, car: car)
      get '/api/v1/chats?limit=5', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.size).to eq(5)
    end

    it 'caps limit at 50' do
      create_list(:chat, 55, account: account, car: car)
      get '/api/v1/chats?limit=55', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.size).to eq(50)
    end

    it 'only returns chats belonging to the account' do
      create_list(:chat, 3, account: account, car: car)
      create_list(:chat, 2)

      get '/api/v1/chats', headers: headers

      expect(json_body.size).to eq(3)
    end
  end

  describe 'GET /api/v1/chats/:id' do
    it 'returns 401 when unauthenticated' do
      chat
      get "/api/v1/chats/#{chat.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns chat by id with correct structure' do
      chat
      get "/api/v1/chats/#{chat.id}", headers: headers

      puts json_body
      expect(response).to have_http_status(:ok)
      expect(json_body).to have_key('chat')
      expect(json_body['chat']).to have_key('id')
      expect(json_body['chat']).to have_key('category')
      expect(json_body['chat']).to have_key('title')
      expect(json_body).to have_key('messages')
    end

    it 'returns error when accessing others chat by id' do
      other_chat = create(:chat)

      get "/api/v1/chats/#{other_chat.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq("Chat not found")
    end
  end

  describe 'DELETE /api/v1/chats/:id' do
    it 'returns 401 when unauthenticated' do
      chat
      delete "/api/v1/chats/#{chat.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'deletes the chat and returns no content' do
      chat
      expect {
        delete "/api/v1/chats/#{chat.id}", headers: headers
      }.to change(Chat, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 when deleting chat from another account' do
      other_chat = create(:chat)
      delete "/api/v1/chats/#{other_chat.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
