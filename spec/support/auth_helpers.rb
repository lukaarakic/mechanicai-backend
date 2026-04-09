module AuthHelpers
  def auth_headers(user)
    post '/api/v1/login', params: { login: account.email, password: 'password' }, as: :json
    token = response.headers['Authorization']
    { 'Authorization' => token }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end