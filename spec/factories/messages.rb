FactoryBot.define do
  factory :message do
    association :chat

    content { Faker::Lorem.sentence }
    role { "user" }
  end
end
