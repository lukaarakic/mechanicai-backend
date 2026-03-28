require "openai"

class Api::V1::MessagesController < ApplicationController
  def create
    chat = current_account.chats.find(params[:chat_id])
    ai_message = DiagnosticMessageService.new(chat).call(params[:content])
    render json: ai_message, status: :created

  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Chat not found" }, status: :not_found
  rescue => e
    render json: { errors: e.message }, status: :internal_server_error
  end
end
