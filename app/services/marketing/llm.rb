require "openai"

module Marketing
  # Structured-output calls for the marketing generators (lib/tasks/marketing.rake).
  # Uses the same OpenAI settings as DiagnosticMessageService and the Pro model, so
  # generated content matches what the app tells users.
  module Llm
    class Error < StandardError; end

    REQUEST_TIMEOUT = 120

    def self.json(system:, user:, name:, schema:, max_tokens: 8192)
      response = client.chat(
        parameters: {
          model: ENV.fetch("OPENAI_MODEL_PRO", "gpt-5.4-mini"),
          response_format: { type: "json_schema", json_schema: { name: name, strict: true, schema: schema } },
          messages: [ { role: "system", content: system }, { role: "user", content: user } ],
          max_completion_tokens: max_tokens,
          **reasoning_params
        }
      )
      raise Error, "reply was cut off by the token limit" if response.dig("choices", 0, "finish_reason") == "length"

      parsed = JSON.parse(response.dig("choices", 0, "message", "content").to_s)
      raise Error, "reply is not a JSON object" unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      raise Error, "reply is not valid JSON: #{e.message}"
    end

    # Text-to-speech as MP3 bytes.
    def self.speech(text, voice:, instructions:)
      client.audio.speech(
        parameters: {
          model: ENV.fetch("OPENAI_TTS_MODEL", "gpt-4o-mini-tts"),
          input: text,
          voice: voice,
          instructions: instructions,
          response_format: "mp3"
        }
      )
    end

    def self.client
      OpenAI::Client.new(
        access_token: ENV.fetch("OPENAI_API_KEY"),
        uri_base: ENV.fetch("OPENAI_URI_BASE", "https://api.openai.com/"),
        request_timeout: REQUEST_TIMEOUT
      )
    end

    def self.reasoning_params
      effort = ENV["OPENAI_REASONING_EFFORT"].presence
      effort ? { reasoning_effort: effort } : {}
    end

    private_class_method :client, :reasoning_params
  end
end
