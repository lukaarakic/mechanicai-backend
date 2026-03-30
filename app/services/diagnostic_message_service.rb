require "openai"

class DiagnosticMessageService
  def initialize(chat, is_subscribed)
    @chat = chat
    @is_subscribed = is_subscribed
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

    model = @is_subscribed ? "gpt-5.4-mini" : "gpt-5.4-nano"

    response = client.chat(
      parameters: {
        model: model,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system_prompt },
          *history,
          *extra_reminder
        ],
        max_completion_tokens: @is_subscribed ? 2048 : 4096
      }
    )

    parsed = JSON.parse(response.dig("choices", 0, "message", "content"))

    @chat.update(title: parsed["title"], category: parsed["category"]) if @chat.title.nil? && parsed["title"].present?
    @chat.messages.create!(role: "assistant", content: parsed["content"])

  rescue Faraday::BadRequestError => e
    puts "🚨 OPENAI REJECTED THE REQUEST!"
    puts e.response[:body]
  rescue JSON::ParserError => e
    puts "🚨 THE AI RETURNED INVALID JSON: #{e.message}"
    puts "Raw output was: #{raw_content}"
  rescue ActiveRecord::RecordInvalid => e
    puts "🚨 DATABASE VALIDATION FAILED: #{e.message}"
  rescue StandardError => e
    puts "🚨 RUBY CRASHED: #{e.class} - #{e.message}"
    puts e.backtrace.first(5)
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
        
        You have gathered enough information. You MUST now provide a final, definitive diagnosis. 
        UNDER NO CIRCUMSTANCES should you ask any more diagnostic questions. 
  
        Respond strictly with a JSON object with the following keys:
        - title: A short descriptive title (max 8 words).
        - category: Exactly one of: SUSPENSION, ENGINE, BRAKES, TRANSMISSION, STEERING, BATTERY, FUEL_SYSTEM, COOLING, ELECTRICAL, EXHAUST, TIRES, SENSORS, UNKNOWN.
        - content: Your full diagnosis formatted in Markdown. The content string MUST be structured with exactly these four headers:
          ## Most Likely Causes
          [Text here]
          ## Severity
          [Text here]
          ## Can You Fix This Yourself?
          [Text here]
          ## Estimated Repair Cost
          [Text here]
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