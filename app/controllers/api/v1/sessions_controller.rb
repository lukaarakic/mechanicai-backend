# frozen_string_literal: true

class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json


  private
  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: { message: "Logged in successfully" }, status: :ok
    else
      render json: { errors: "Invalid email or password" }, status: :unauthorized
    end
  end

  def respond_to_on_destroy
    render json: { message: "Logged out successfully" }, status: :ok
  end
end
