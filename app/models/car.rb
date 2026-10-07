class Car < ApplicationRecord
  belongs_to :account
  has_many :chats, dependent: :destroy

  validates :make,  presence: true, length: { maximum: 50 }
  validates :model, presence: true, length: { maximum: 50 }
  validates :year,  presence: true, numericality: { only_integer: true, greater_than: 1885, less_than_or_equal_to: ->(_) { Date.current.year + 1 } }
  validates :size,  presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 10_000 }
  validates :power, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 2_000 }
end
