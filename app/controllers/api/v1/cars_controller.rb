class Api::V1::CarsController < ApplicationController
  def create
    if !is_subscribed && current_account.cars.count >= 1
      render json: { error: "Upgrade to Pro plan to add more cars" }, status: :unprocessable_entity
      return
    end

    car = current_account.cars.new(car_params)

    if car.save
      render json: car, status: :created
    else
      render json: { error: car.errors }, status: :unprocessable_entity
    end
  end

  def show
    car = current_account.cars.find(params[:id])
    render json: car, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Car not found" }, status: :not_found
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
      render json: { error: car.errors }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Car not found" }, status: :not_found
  end

  def destroy
    car = current_account.cars.find(params[:id])
    car.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Car not found" }, status: :not_found
  end

  private

  def car_params
    params.expect(car: [ :make, :model, :year, :power, :size ])
  end
end
