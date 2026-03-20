class Car < ApplicationRecord
  has_many :chats, dependent: :destroy
end
