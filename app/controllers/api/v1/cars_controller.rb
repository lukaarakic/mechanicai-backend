class Api::V1::CarsController < ApplicationController
  def create
    car = Car.new(car_params)

    if car.save
      render json: car, status: :created
    else
      render json: { errors: car.errors }, status: :unprocessable_entity
    end
  end

  def show
    car = Car.find(params[:id])
    render json: car, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Car not found" }, status: :not_found
  end

  def index
    cars = Car.all
    render json: cars, status: :ok
  end

  def update
    car = Car.find(params[:id])

    if car.update(car_params)
      render json: car, status: :ok
    else
      render json: { errors: car.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Car not found" }, status: :not_found
  end

  private

  def car_params
    params.expect(car: [ :make, :model, :year, :power, :size ])
  end
end
