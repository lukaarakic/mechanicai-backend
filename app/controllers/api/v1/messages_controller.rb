class Api::V1::MessagesController < ApplicationController
  MAX_CONTENT_LENGTH = 4000

  def create
    chat = current_account.chats.find(params[:chat_id])

    content = message_content
    if content.blank?
      render json: { error: "Message content is required" }, status: :unprocessable_entity
      return
    end

    if content.length > MAX_CONTENT_LENGTH
      render json: { error: "Message content is too long" }, status: :unprocessable_entity
      return
    end

    if !is_subscribed && chat.free_messages_remaining.zero?
      render json: { error: "Free chats are limited to #{Chat::FREE_USER_MESSAGES_PER_CHAT} messages. Upgrade to Pro to keep asking." }, status: :forbidden
      return
    end

    ai_message = DiagnosticMessageService.new(chat, is_subscribed).call(content)
    render json: ai_message, status: :created

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found" }, status: :not_found
  rescue DiagnosticMessageService::OffTopicError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Message creation failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to process message" }, status: :internal_server_error
  end

  private

  def message_content
    return params.expect(:content).to_s.strip if params.key?(:content)

    params.expect(message: [ :content ])[:content].to_s.strip
  rescue ActionController::ParameterMissing
    nil
  end
end
