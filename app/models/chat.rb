class Chat < ApplicationRecord
  belongs_to :car
  belongs_to :account
  has_many :messages, dependent: :destroy

  validate :car_belongs_to_account

  private

  def car_belongs_to_account
    return if car.blank? || account.blank?
    return if car.account_id == account_id

    errors.add(:car_id, "must belong to the current account")
  end
end
