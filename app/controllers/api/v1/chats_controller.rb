class Api::V1::ChatsController < ApplicationController
  def create
    chat = Chat.new(chat_params)

    if chat.save
      render json: chat, status: :created
    else
      render json: { errors: car.errors }, status: :unprocessable_entity
    end
  end

  def show
    chat = Chat.find(params[:id])
    render json: chat, status: :ok
  rescue
    render json: { errors: "Chat not found" }, status: :unprocessable_entity
  end

  def index
    chats = Chat.all
    render json: chats, status: :ok
  end

  private
  def chat_params
    params.expect(chat: [ :car_id ])
  end
end
