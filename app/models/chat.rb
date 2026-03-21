class Chat < ApplicationRecord
  belongs_to :user
  belongs_to :car
  has_many :messages, dependent: :destroy
end
