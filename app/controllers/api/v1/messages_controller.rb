require "openai"

class Api::V1::MessagesController < ApplicationController
  def create
    chat = current_account.chats.find(params[:chat_id])

    user_message_count = chat.messages.where(role: "user").count
    puts "USER MESSAGE COUNT: #{user_message_count}"

    chat.messages.create!(
      role: "user",
      content: params[:content],
      )

    history = chat.messages.map do |message|
      { role: message[:role], content: message[:content] }
    end


    system_prompt = case user_message_count
    when 0
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{chat.car.year} #{chat.car.make} #{chat.car.model}, #{chat.car.size}cc, #{chat.car.power}hp.
        The user just described their problem. Do NOT diagnose yet.
        Ask ONE single smart diagnostic question. Keep it short and conversational.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    when 1
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{chat.car.year} #{chat.car.make} #{chat.car.model}, #{chat.car.size}cc, #{chat.car.power}hp.
        You already asked one question. Do NOT diagnose yet.
        Ask ONE more targeted diagnostic question. Keep it short and conversational.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    when 2
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{chat.car.year} #{chat.car.make} #{chat.car.model}, #{chat.car.size}cc, #{chat.car.power}hp.
        You have asked two questions. You MUST ask ONE final question before diagnosing.
        Do NOT diagnose yet under any circumstances. Keep it short and conversational.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    when 3
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{chat.car.year} #{chat.car.make} #{chat.car.model}, #{chat.car.size}cc, #{chat.car.power}hp.
        You have gathered enough information. Provide a full diagnosis.
        Set title to a short descriptive title max 8 words.
        Set category to exactly one of: SUSPENSION, ENGINE, BRAKES, TRANSMISSION, STEERING, BATTERY, FUEL_SYSTEM, COOLING, ELECTRICAL, EXHAUST, TIRES, SENSORS, UNKNOWN.
        Write content in markdown with these sections: ## Most Likely Causes, ## Severity, ## Can You Fix This Yourself?, ## Estimated Repair Cost.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    else
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{chat.car.year} #{chat.car.make} #{chat.car.model}, #{chat.car.size}cc, #{chat.car.power}hp.
        You already provided a diagnosis. Answer the user's follow up question in markdown.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    end

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    extra_reminder = user_message_count < 3 ? [{ role: "system", content: "Remember: Ask exactly ONE diagnostic question now. Do NOT diagnose yet." }] : []
    puts "SENDING TO OPENAI: #{system_prompt}"
    response = client.chat(
      parameters: {
        model: "gpt-4o",
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt },
          *history,
          *extra_reminder
        ],
        max_tokens: 500
      }
    )

    ai_content = response.dig("choices", 0, "message", "content")
    parsed = JSON.parse(ai_content)


    chat.update(title: parsed["title"], category: parsed["category"]) if chat.title.nil? && parsed["title"].present?

    ai_message = chat.messages.create!(
      role: "assistant",
      content: parsed["content"],
      )

    render json: ai_message, status: :created

  rescue => e
    puts "FULL ERROR: #{e.message}"
    puts "FULL ERROR CLASS: #{e.class}"
    render json: { errors: e.message }, status: :internal_server_error
  rescue ActiveRecord::RecordNotFound
    render json: { errors: "Session not found" }, status: :not_found
  rescue => e
    render json: { errors: e.message }, status: :internal_server_error
  end
end
