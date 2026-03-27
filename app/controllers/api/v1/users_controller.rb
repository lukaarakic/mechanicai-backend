class Api::V1::UsersController < ApplicationController
  def current_user
    if current_account.nil?
      render json: { errors: ["Account not found"] }, status: :not_found
    end

    render json: current_account.as_json(only: [:id, :first_name, :last_name, :email, :avatar]), status: :ok
  end
end
