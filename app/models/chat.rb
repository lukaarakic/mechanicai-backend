class Chat < ApplicationRecord
  CATEGORIES = %w[
    SUSPENSION ENGINE BRAKES TRANSMISSION STEERING BATTERY FUEL_SYSTEM
    COOLING ELECTRICAL EXHAUST TIRES SENSORS UNKNOWN
  ].freeze
  TITLE_MAX_LENGTH = 100

  # Free plan: 3 answers to the diagnostic questions, the message that gets the
  # diagnosis, and 2 follow-ups.
  FREE_USER_MESSAGES_PER_CHAT = 6

  belongs_to :car
  belongs_to :account
  has_many :messages, -> { order(:created_at) }, dependent: :destroy

  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :title, length: { maximum: TITLE_MAX_LENGTH }
  validate :car_belongs_to_account

  def user_message_count
    messages.where(role: "user").count
  end

  def free_messages_remaining
    [ FREE_USER_MESSAGES_PER_CHAT - user_message_count, 0 ].max
  end

  private

  def car_belongs_to_account
    return if car.blank? || account.blank?
    return if car.account_id == account_id

    errors.add(:car_id, "must belong to the current account")
  end
end
