module AuthHelpers
  def auth_headers(user)
    post '/api/v1/login', params: { email: account.email, password: 'password' }, as: :json
    puts "Login status in helper: #{response.status}"
    puts "Login body: #{response.body}"
    token = response.headers['Authorization']
    { 'Authorization' => token }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end