require "openai"

class DiagnosticMessageService
  def initialize(chat)
    @chat = chat
  end

  def call(content)
    user_message_count = @chat.messages.where(role: "user").count

    @chat.messages.create!(role: "user", content: content)

    history = @chat.messages.map do |message|
      { role: message[:role], content: message[:content] }
    end

    system_prompt = build_prompt(user_message_count)
    extra_reminder = user_message_count < 3 ? [{ role: "system", content: "Remember: Ask exactly ONE diagnostic question now. Do NOT diagnose yet." }] : []

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

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

    parsed = JSON.parse(response.dig("choices", 0, "message", "content"))

    @chat.update(title: parsed["title"], category: parsed["category"]) if @chat.title.nil? && parsed["title"].present?

    @chat.messages.create!(role: "assistant", content: parsed["content"])
  end

  private

  def build_prompt(user_message_count)
    car = @chat.car
    car_info = "#{car.year} #{car.make} #{car.model}, #{car.size}cc, #{car.power}hp"

    case user_message_count
    when 0
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{car_info}.
        The user just described their problem. Do NOT diagnose yet.
        Ask ONE single smart diagnostic question. Keep it short and conversational.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    when 1
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{car_info}.
        You already asked one question. Do NOT diagnose yet.
        Ask ONE more targeted diagnostic question. Keep it short and conversational.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    when 2
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{car_info}.
        You have asked two questions. You MUST ask ONE final question before diagnosing.
        Do NOT diagnose yet under any circumstances. Keep it short and conversational.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    when 3
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{car_info}.
        You have gathered enough information. Provide a full diagnosis.
        Set title to a short descriptive title max 8 words.
        Set category to exactly one of: SUSPENSION, ENGINE, BRAKES, TRANSMISSION, STEERING, BATTERY, FUEL_SYSTEM, COOLING, ELECTRICAL, EXHAUST, TIRES, SENSORS, UNKNOWN.
        Write content in markdown with these sections: ## Most Likely Causes, ## Severity, ## Can You Fix This Yourself?, ## Estimated Repair Cost.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    else
      <<~PROMPT
        You are an expert automotive mechanic with 20+ years of experience.
        The user is driving a #{car_info}.
        You already provided a diagnosis. Answer the user's follow up question in markdown.
        Set title and category to null.
        Respond with a JSON object with keys: title, category, content.
      PROMPT
    end
  end
end