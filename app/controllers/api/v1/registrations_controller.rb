class Api::V1::RegistrationsController < Devise::RegistrationsController
  respond_to :json

  private

  def sign_up_params
    params.expect(user: [:email, :password, :password_confirmation])
  end

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: { message: "Signed up successfully" }, status: :created
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end
end