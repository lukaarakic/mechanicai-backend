# Paddle credentials are read from ENV (or credentials):
#   PADDLE_BILLING_API_KEY, PADDLE_BILLING_CLIENT_TOKEN,
#   PADDLE_BILLING_SIGNING_SECRET, PADDLE_BILLING_ENVIRONMENT (sandbox|production)
# Point the Paddle notification destination at POST /pay/webhooks/paddle_billing.
Pay.setup do |config|
  config.business_name = "DashClue"
  config.support_email = ENV.fetch("SUPPORT_EMAIL", "support@lukarakic.me")
  config.enabled_processors = [ :paddle_billing ]

  # Paddle sends its own receipts and billing emails.
  config.send_emails = false
end
