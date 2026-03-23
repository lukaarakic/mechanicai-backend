class Api::V1::PaymentController < ApplicationController
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
    subscription = current_account.payment_processor.subscription

    if subscription.nil? || subscription.canceled?
      return render json: { errors: "No active subscription found." }, status: :unprocessable_entity
    end

    subscription.cancel

    render json: { message: "Subscription canceled" }, status: :ok
  end
end