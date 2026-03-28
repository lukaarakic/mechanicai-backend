class Api::V1::ChatsController < ApplicationController
  def create
    chat = current_account.chats.new(chat_params)

    if chat.save
      ai_message = ::DiagnosticMessageService.new(chat).call(params[:chat][:message])
      render json: { chat: chat, message: ai_message }, status: :created
    else
      render json: { errors: chat.errors }, status: :unprocessable_entity
    end
  end

  def show
    chat = current_account.chats.find(params[:id])
    render json: { chat: chat, messages: chat.messages }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Chat not found" }, status: :unprocessable_entity
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
    render json: { errors: "Chat not found." }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotDestroyed
    render json: { errors: "Something went wrong." }, status: :unprocessable_entity
  end

  private
  def chat_params
    params.expect(chat: [ :car_id ])
  end
end
