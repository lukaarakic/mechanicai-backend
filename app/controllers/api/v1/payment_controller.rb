class Api::V1::PaymentController < ApplicationController

  def status
    processor = current_account.payment_processor

    if processor.subscribed?
      subscription = processor.subscription
      render json: {
        subscribed: true,
        status: subscription.status,
        plan: subscription.name,
        renews_at: subscription.current_period_end,
        cancel_at_period_end: subscription.ends_at.present?
      }
    else
      render json: { subscribed: false }
    end
  rescue StandardError => e
    Rails.logger.error("Payment status failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to fetch subscription status" }, status: :internal_server_error
  end
  def subscribe
    current_account.payment_processor.api_record
    processor = current_account.payment_processor

    if processor.subscribed?
      return render json: { error: "Already Subscribed" }, status: :unprocessable_entity
    end


    render json: { customer_id: processor.processor_id }
  rescue StandardError => e
    Rails.logger.error("Payment subscribe failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to start subscription" }, status: :internal_server_error
  end

  def cancel
    current_account.payment_processor.subscription.cancel
    render json: { success: true }
  rescue StandardError => e
    Rails.logger.error("Payment cancel failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to cancel subscription" }, status: :internal_server_error
  end
end
