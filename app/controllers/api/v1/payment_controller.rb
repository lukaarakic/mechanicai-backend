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
  rescue => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end
  def subscribe
    current_account.payment_processor.api_record
    processor = current_account.payment_processor

    if processor.subscribed?
      return render json: { errors: "Already Subscribed" }, status: :unprocessable_entity
    end


    render json: { customer_id: processor.processor_id }
  rescue => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end

  def cancel
    current_account.payment_processor.subscription.cancel
    render json: { success: true }
  rescue => e
    render json: { errors: e.message }, status: :unprocessable_entity
  end
end
