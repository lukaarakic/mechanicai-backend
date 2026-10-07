# Fail at boot instead of on the first request when production config is missing.
if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  required = %w[
    DATABASE_URL
    JWT_SECRET
    FRONTEND_URL
    INTERNAL_API_SECRET
    OPENAI_API_KEY
    RESEND_API_KEY
    PADDLE_BILLING_API_KEY
    PADDLE_BILLING_CLIENT_TOKEN
    PADDLE_BILLING_SIGNING_SECRET
  ]
  missing = required.select { |name| ENV[name].blank? }

  raise "Missing required environment variables: #{missing.join(", ")}" if missing.any?
end
