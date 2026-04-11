FactoryBot.define do
  factory :car do
    make { 'Toyota' }
    model { 'Corola' }
    year { 1999 }
    size { 2000 }
    power { 110 }
    association :account, factory: :account
  end
end
