require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      message = build(:message)

      expect(message).to be_valid
    end

    it 'is invalid without chat' do
      message = build(:message, chat: nil)
      expect(message).to_not be_valid
    end

    it 'is invalid without content' do
      message = build(:message, content: nil)
      expect(message).to_not be_valid
    end

    it 'is invalid without role' do
      message = build(:message, role: nil)
      expect(message).to_not be_valid
    end

    it 'is invalid with an unknown role' do
      message = build(:message, role: 'unknown')
      expect(message).to_not be_valid
    end
  end

  describe "associations" do
    it 'belongs to a chat' do
      association = Message.reflect_on_association(:chat)
      expect(association.macro).to eq(:belongs_to)
    end
  end
end
