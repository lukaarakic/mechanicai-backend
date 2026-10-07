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
      render json: { error: "Something went wrong", errors: current_account.errors.to_hash(true) }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound
    render json: { error: "User not found" }, status: :not_found
  end

  def onboard
    if current_account.onboarding_done?
      render json: { error: "Already onboarded" }, status: :unprocessable_entity
      return
    end

    unless onboard_params[:profile].present? && onboard_params[:car].present?
      render json: { error: "Profile and car details are required" }, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      current_account.update!(onboard_params[:profile].merge(onboarding_done: true))
      current_account.cars.create!(onboard_params[:car])
    end

    render json: current_account_payload, status: :ok

  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Onboarding failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to complete onboarding", errors: e.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  private
  def current_account_payload
    current_account.as_json(only: [ :id, :first_name, :last_name, :email, :avatar, :onboarding_done, :distance_unit ]).merge(
      subscribed: is_subscribed,
      free_chats_remaining: is_subscribed ? nil : current_account.free_chats_remaining
    )
  end

  def onboard_params
    params.permit(profile: [ :first_name, :last_name, :avatar ], car: [ :make, :model, :year, :power, :size ])
  end

  def update_params
    params.permit(:first_name, :last_name, :distance_unit)
  end
end
