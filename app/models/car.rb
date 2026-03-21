class Car < ApplicationRecord
  has_many :chats, dependent: :destroy
  belongs_to :user
end
