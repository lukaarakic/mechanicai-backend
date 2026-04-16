require 'rails_helper'

RSpec.describe 'Messages' do
  let(:account) { create(:account) }
  let(:car) { create(:car, account: account) }
  let(:chat) { create(:chat, account: account, car: car) }
  let(:headers) { auth_headers(account) }
  let(:service_double) { double('DiagnosticMessageService') }

  before do
    allow(DiagnosticMessageService).to receive(:new).and_return(service_double)
    allow(service_double).to receive(:call).and_return({ role: 'assistant', content: 'Check your brakes' })
  end

  describe 'POST /api/v1/chats/:chat_id/messages' do
    let(:valid_params) { { content: "My car makes a grinding noise" } }

    it 'returns 401 when unauthenticated' do
      post "/api/v1/chats/#{chat.id}/messages", params: valid_params
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a message with valid params' do
      post "/api/v1/chats/#{chat.id}/messages", headers: headers, params: valid_params
      expect(response).to have_http_status(:created)
    end

    it 'also accepts nested message[content] format' do
      post "/api/v1/chats/#{chat.id}/messages", headers: headers, params: { message: { content: "grinding noise" } }
      expect(response).to have_http_status(:created)
    end

    it 'returns 404 when chat belongs to another account' do
      other_chat = create(:chat)
      post "/api/v1/chats/#{other_chat.id}/messages", headers: headers, params: valid_params
      expect(response).to have_http_status(:not_found)
      expect(json_body['error']).to eq('Chat not found')
    end

    it 'returns 404 when chat does not exist' do
      post "/api/v1/chats/99999/messages", headers: headers, params: valid_params
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 when content is blank' do
      post "/api/v1/chats/#{chat.id}/messages", headers: headers, params: { content: '' }
      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Message content is required')
    end

    it 'returns 422 when content is missing entirely' do
      post "/api/v1/chats/#{chat.id}/messages", headers: headers, params: {}
      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Message content is required')
    end

    it 'returns 422 when content exceeds 4000 characters' do
      post "/api/v1/chats/#{chat.id}/messages", headers: headers, params: { content: 'a' * 4001 }
      expect(response).to have_http_status(422)
      expect(json_body['error']).to eq('Message content is too long')
    end

    it 'returns 500 when DiagnosticMessageService raises' do
      allow(service_double).to receive(:call).and_raise(StandardError, "OpenAI timeout")
      post "/api/v1/chats/#{chat.id}/messages", headers: headers, params: valid_params
      expect(response).to have_http_status(:internal_server_error)
      expect(json_body['error']).to eq('Unable to process message')
    end
  end
end