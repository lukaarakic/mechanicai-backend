class Account < ApplicationRecord
  include Rodauth::Rails.model
  enum :status, { unverified: 1, verified: 2, closed: 3 }
  pay_customer default_payment_processor: :paddle_billing
  has_many :chats, dependent: :destroy
  has_many :cars, dependent: :destroy

end
