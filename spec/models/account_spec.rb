require 'rails_helper'

RSpec.describe Account, type: :model do
  describe 'validations' do
    it 'destroys cars when account is destroyed' do
      account = create(:account)
      create_list(:car, 3, account: account)

      expect{ account.destroy }.to change(Car, :count).by(-3)
    end

    it 'destroys chats when account is destroyed' do
      account = create(:account)
      create_list(:chat, 3, account: account)

      expect{ account.destroy }.to change(Chat, :count).by(-3)
    end

    it 'has correct enum values' do
      expect(Account.statuses).to eq({ 'unverified' => 1, 'verified' => 2, 'closed' => 3 })
    end
  end
end
