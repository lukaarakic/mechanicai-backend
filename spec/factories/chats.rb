FactoryBot.define do
  factory :chat do
    association :account

    car { association :car, account: account }
  end
end
