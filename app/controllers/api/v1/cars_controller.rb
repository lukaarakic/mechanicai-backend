class Api::V1::CarsController < ApplicationController
  def create
    car = Car.new(car_params)
    car.account_id = rodauth.account_id

    if car.save
      render json: car, status: :created
    else
      render json: { errors: car.errors }, status: :unprocessable_entity
    end
  end

  def show
    car = current_account.cars.find(params[:id])
    render json: car, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Car not found" }, status: :not_found
  end

  def index
    cars = current_account.cars.all
    render json: cars, status: :ok
  end

  def update
    car = current_account.cars.find(params[:id])

    if car.update(car_params)
      render json: car, status: :ok
    else
      render json: { errors: car.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Car not found" }, status: :not_found
  end

  def destroy
    car = current_account.cars.find(params[:id])
    if car.destroy
      render json: car, status: :ok
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Car not found" }, status: :not_found
  end

  private

  def car_params
    params.expect(car: [ :make, :model, :year, :power, :size, :default_car ])
  end
end
