class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle("api/ip", limit: 300, period: 5.minutes) do |request|
    request.ip if request.path.start_with?("/api/v1")
  end

  throttle("auth/ip", limit: 20, period: 1.minute) do |request|
    request.ip if request.post? && request.path.match?(%r{\A/api/v1/(login|register)\z})
  end

  throttle("ai/ip", limit: 30, period: 1.minute) do |request|
    next unless request.post?

    if request.path == "/api/v1/chats" || request.path.match?(%r{\A/api/v1/chats/[^/]+/messages\z})
      request.ip
    end
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Rate limit exceeded" }.to_json ]
    ]
  end
end

Rack::Attack.enabled = !Rails.env.test?