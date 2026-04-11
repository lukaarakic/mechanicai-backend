require 'rails_helper'

RSpec.describe Car, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      car = build(:car)

      expect(car).to be_valid
    end

    it "is invalid without a make" do
      car = build(:car, make: nil)

      expect(car).to_not be_valid
      expect(car.errors[:make]).to include("can't be blank")
    end

    it "is invalid without a model" do
      car = build(:car, model: nil)

      expect(car).to_not be_valid
      expect(car.errors[:model]).to include("can't be blank")
    end

    it "is invalid if year is not a number" do
      car = build(:car, year: "not a number")

      expect(car).to_not be_valid
      expect(car.errors[:year]).to include("is not a number")
    end

    it "is invalid if size is not a number" do
      car = build(:car, size: "not a number")

      expect(car).to_not be_valid
      expect(car.errors[:size]).to include("is not a number")
    end

    it "is invalid if power is not a number" do
      car = build(:car, power: "not a number")

      expect(car).to_not be_valid
      expect(car.errors[:power]).to include("is not a number")
    end
  end

  describe "associations" do
    it "belongs to account" do
      association = Car.reflect_on_association(:account)

      expect(association.macro).to eq(:belongs_to)
    end
  end
end
