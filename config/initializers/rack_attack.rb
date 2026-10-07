require "jwt"

# The Next.js server calls this API on behalf of every user, so request.ip is
# the frontend server's IP for all traffic. The frontend forwards the real
# client IP in X-Client-IP together with a shared secret; we only trust that
# header when the secret matches. Authenticated limits are keyed by account.
class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  INTERNAL_SECRET = ENV["INTERNAL_API_SECRET"].presence

  def self.client_ip(request)
    forwarded = request.get_header("HTTP_X_CLIENT_IP").to_s.split(",").first.to_s.strip
    secret = request.get_header("HTTP_X_INTERNAL_SECRET").to_s

    if forwarded.present? && INTERNAL_SECRET && ActiveSupport::SecurityUtils.secure_compare(secret, INTERNAL_SECRET)
      forwarded
    else
      request.ip
    end
  end

  # Account id from a valid JWT, falling back to the client IP.
  def self.account_or_ip(request)
    token = request.get_header("HTTP_AUTHORIZATION").to_s.delete_prefix("Bearer ").strip
    if token.present? && (secret = ENV["JWT_SECRET"].presence)
      payload = JWT.decode(token, secret, true, algorithm: "HS256").first
      return "account:#{payload["account_id"]}" if payload["account_id"]
    end
    "ip:#{client_ip(request)}"
  rescue JWT::DecodeError
    "ip:#{client_ip(request)}"
  end

  def self.login_param(request)
    return unless request.media_type == "application/json"

    body = request.body.read
    request.body.rewind
    JSON.parse(body)["email"].to_s.downcase.strip.presence
  rescue JSON::ParserError
    nil
  end

  AUTH_PATHS = %r{\A/api/v1/(login|register|reset-password-request|reset-password|verify-account|verify-account-resend)\z}
  SENSITIVE_ACCOUNT_PATHS = %r{\A/api/v1/(change-password|close-account)\z}
  AI_PATHS = %r{\A/api/v1/chats(/[^/]+/messages)?\z}

  throttle("api/client", limit: 300, period: 5.minutes) do |request|
    account_or_ip(request) if request.path.start_with?("/api/v1")
  end

  throttle("auth/ip", limit: 20, period: 1.minute) do |request|
    client_ip(request) if request.post? && request.path.match?(AUTH_PATHS)
  end

  # Slow down credential stuffing and email flooding against one address.
  throttle("auth/email", limit: 5, period: 5.minutes) do |request|
    login_param(request) if request.post? && request.path.match?(AUTH_PATHS)
  end

  throttle("account/sensitive", limit: 5, period: 5.minutes) do |request|
    account_or_ip(request) if request.post? && request.path.match?(SENSITIVE_ACCOUNT_PATHS)
  end

  throttle("ai/client", limit: 10, period: 1.minute) do |request|
    account_or_ip(request) if request.post? && request.path.match?(AI_PATHS)
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Too many requests. Please wait a moment and try again." }.to_json ]
    ]
  end
end

Rack::Attack.enabled = !Rails.env.test?
