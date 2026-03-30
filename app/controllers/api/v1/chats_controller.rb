class Api::V1::ChatsController < ApplicationController
  def create
    unless is_subscribed
      start_of_month = Time.current.beginning_of_month
      end_of_month = Time.current.end_of_month

      chat_count = current_account.chats.where(created_at: start_of_month..end_of_month).count

      if chat_count >=3
        render json: { error: "You've reached your free limit of 3 chats per month." }, status: :forbidden
        return
      end
    end

    chat = current_account.chats.new(chat_params)

    if chat.save
      ai_message = ::DiagnosticMessageService.new(chat, is_subscribed).call(params[:chat][:message])
      render json: { chat: chat, message: ai_message }, status: :created
    else
      render json: { error: chat.errors }, status: :unprocessable_entity
    end
  end

  def show
    chat = current_account.chats.find(params[:id])
    render json: { chat: chat, messages: chat.messages }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found" }, status: :unprocessable_entity
  end

  def index
    limit = params[:limit] || 10
    chats = current_account.chats.includes(:car).order(created_at: :desc).limit(limit)
    render json: chats.as_json(include: :car), status: :ok
  end

  def destroy
    chat = current_account.chats.find(params[:id])
    chat.destroy!
    render json: { success: true }, status: :ok

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found." }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotDestroyed
    render json: { error: "Something went wrong." }, status: :unprocessable_entity
  end

  private
  def chat_params
    params.expect(chat: [ :car_id ])
  end
end
