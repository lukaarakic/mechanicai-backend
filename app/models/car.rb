class Car < ApplicationRecord
  belongs_to :account
  has_many :chats, dependent: :destroy
end
