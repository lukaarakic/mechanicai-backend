class Api::V1::ChatsController < ApplicationController
  MAX_CONTENT_LENGTH = 4000

  def create
    content = chat_message_content
    if content.blank?
      render json: { error: "Message content is required" }, status: :unprocessable_entity
      return
    end

    if content.length > MAX_CONTENT_LENGTH
      render json: { error: "Message content is too long" }, status: :unprocessable_entity
      return
    end

    car = current_account.cars.find(chat_params[:car_id])

    # Lock the account so parallel requests can't both pass the free limit.
    chat = current_account.with_lock do
      current_account.chats.create!(car: car) unless free_limit_reached?
    end

    if chat.nil?
      render json: { error: "You've reached your free limit of #{Account::FREE_CHATS_PER_MONTH} chats per month." }, status: :forbidden
      return
    end

    begin
      ai_message = ::DiagnosticMessageService.new(chat, is_subscribed).call(content)
    rescue StandardError
      # Don't leave an empty chat behind or count it against the free quota.
      chat.destroy
      raise
    end

    render json: { chat: chat, message: ai_message }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Car not found" }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue DiagnosticMessageService::OffTopicError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Chat creation failed for account=#{rodauth.account_id}: #{e.class} #{e.message}")
    render json: { error: "Unable to create chat. Please try again." }, status: :internal_server_error
  end

  def show
    chat = current_account.chats.find(params[:id])
    render json: {
      chat: chat.slice(:id, :category, :title),
      messages: chat.messages.as_json(only: [ :id, :role, :content, :diagnosis, :created_at ]),
      messages_remaining: is_subscribed ? nil : chat.free_messages_remaining
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found" }, status: :not_found
  end

  # History is a Pro feature. Paginate with ?before=<created_at of last item>.
  def index
    unless is_subscribed
      render json: { error: "Upgrade to Pro to see your history." }, status: :forbidden
      return
    end

    limit = params[:limit].to_i
    limit = 10 if limit <= 0
    limit = [ limit, 50 ].min

    chats = current_account.chats.includes(:car).order(created_at: :desc).limit(limit)
    if params[:before].present?
      before = Time.zone.parse(params[:before].to_s)
      chats = chats.where(created_at: ...before) if before
    end

    render json: chats.as_json(include: :car), status: :ok
  rescue ArgumentError
    render json: { error: "Invalid before parameter" }, status: :unprocessable_entity
  end

  def destroy
    chat = current_account.chats.find(params[:id])
    chat.destroy!
    head :no_content

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Chat not found." }, status: :not_found
  rescue ActiveRecord::RecordNotDestroyed
    render json: { error: "Something went wrong." }, status: :unprocessable_entity
  end

  private
  def chat_params
    params.expect(chat: [ :car_id, :message ])
  end

  def chat_message_content
    chat_params[:message].to_s.strip
  end

  def free_limit_reached?
    return false if is_subscribed

    current_account.free_chats_remaining.zero?
  end
end
