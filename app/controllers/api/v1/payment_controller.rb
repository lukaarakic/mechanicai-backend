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
end
