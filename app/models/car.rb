class Car < ApplicationRecord
  belongs_to :account
  has_many :chats, dependent: :destroy

  validates :make, presence:true
  validates :model, presence: true
  validates :year,  presence: true, numericality: { only_integer: true, greater_than: 1885 }
  validates :size,  presence: true, numericality: { greater_than: 0 }
  validates :power, presence: true, numericality: { greater_than: 0 }
end
