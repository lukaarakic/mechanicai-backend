class Account < ApplicationRecord
  include Rodauth::Rails.model
  enum :status, { unverified: 1, verified: 2, closed: 3 }
  pay_customer default_payment_processor: :paddle_billing
  has_many :chats, dependent: :destroy
  has_many :cars, dependent: :destroy

  # Avatars are generated client-side; only accept the avatar service we render.
  AVATAR_URL_FORMAT = %r{\Ahttps://api\.dicebear\.com/9\.x/[a-z-]+/svg\?seed=[A-Za-z0-9]{1,64}\z}

  DISTANCE_UNITS = %w[km mi].freeze

  validates :first_name, :last_name, length: { maximum: 64 }
  validates :distance_unit, inclusion: { in: DISTANCE_UNITS }
  validates :avatar, format: { with: AVATAR_URL_FORMAT }, allow_blank: true

  FREE_CHATS_PER_MONTH = 3

  def subscribed?
    payment_processor.subscribed?
  end

  def free_chats_remaining
    [ FREE_CHATS_PER_MONTH - chats.where(created_at: Time.current.all_month).count, 0 ].max
  end
end
