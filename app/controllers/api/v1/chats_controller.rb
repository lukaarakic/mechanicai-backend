class Api::V1::ChatsController < ApplicationController
  def create
    chat = Chat.new(chat_params)
    chat.account_id = rodauth.account_id

    if chat.save
      ai_message = ::DiagnosticMessageService.new(chat).call(params[:chat][:message])
      render json: { chat: chat, message: ai_message }, status: :created
    else
      render json: { errors: car.errors }, status: :unprocessable_entity
    end
  end

  def show
    chat = current_account.chats.find(params[:id])
    render json: chat, status: :ok
  rescue
    render json: { errors: "Chat not found" }, status: :unprocessable_entity
  end

  def index
    chats = current_account.chats.all
    render json: chats, status: :ok
  end

  def destroy
    chat = current_account.chats.find(params[:id])

    if chat.destroy
      render json: chat, status: :ok
    end

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
