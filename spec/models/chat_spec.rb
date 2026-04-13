require 'rails_helper'

RSpec.describe Chat, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      chat = build(:chat)

      expect(chat).to be_valid
    end

    it 'is invalid when car belongs to another account' do
      chat = build(:chat, car: create(:car))

      expect(chat).to_not be_valid
      expect(chat.errors[:car_id]).to include("must belong to the current account")
    end

    it 'is invalid when car is blank' do
      chat = build(:chat, car: nil)
      expect(chat).to_not be_valid
    end

    it 'is invalid when account is blank' do
      chat = build(:chat, account: nil)
      expect(chat).to_not be_valid
    end

    it 'destorys messages when chat is destoryed' do
      chat = create(:chat)
      create_list(:message, 3, chat: chat)

      expect{ chat.destroy }.to change(Message, :count).by(-3)
    end
  end

  describe 'associations' do
    it 'belongs to account' do
      association = Chat.reflect_on_association(:account)

      expect(association.macro).to eq(:belongs_to)
    end

    it 'has many messages' do
      association = Chat.reflect_on_association(:messages)
      expect(association.macro).to eq(:has_many)
    end
  end
end
