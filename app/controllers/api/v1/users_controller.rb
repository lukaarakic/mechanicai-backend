class Api::V1::UsersController < ApplicationController
  def current_user
    render json: current_account_payload, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Account not found" }, status: :not_found
  end

  def update_user

    if current_account.update(update_params)
      render json: current_account_payload, status: :ok
    else
      render json: { error: "Something went wrong" }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end

  def onboard
    ActiveRecord::Base.transaction do
      current_account.update!(onboard_params[:profile])
      current_account.cars.create!(onboard_params[:car])
    end

    render json: { success: true }, status: :ok

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Onboarding failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to complete onboarding" }, status: :unprocessable_entity
  end

  private
  def current_account_payload
    subscribed = current_account.payment_processor.subscribed?

    current_account.as_json(only: [ :id, :first_name, :last_name, :email, :avatar, :onboarding_done ]).merge(subscribed: subscribed)
  end

  def onboard_params
    params.permit(profile: [ :first_name, :last_name, :avatar, :onboarding_done ], car: [ :make, :model, :year, :power, :size ])
  end

  def update_params
    params.permit(:first_name, :last_name )
  end
end
