# The structured diagnosis the model returns on the diagnosing turn, rendered
# as a card in the chat (mechanicai-frontend app/components/chat/DiagnosisCard).
#
# SCHEMA is sent as an OpenAI structured-output schema. The model's output is
# still untrusted, so .sanitize keeps only known values and bounded strings,
# and .to_markdown renders the same data as the message's text content, which
# is what the model sees in later turns.
module DiagnosisReport
  SEVERITIES = %w[Low Moderate High Critical].freeze
  DRIVE_SAFETY = %w[safe caution stop].freeze
  LIKELIHOODS = %w[High Medium Low].freeze
  DIY_VERDICTS = %w[yes maybe no].freeze
  DIFFICULTIES = [ "Easy", "Moderate", "Hard", "Workshop only" ].freeze

  MAX_CAUSES = 4
  MAX_STEPS = 8
  MAX_COSTS = 5
  MAX_PRICE = 50_000
  SHORT_TEXT = 120
  LONG_TEXT = 600

  DRIVE_SAFETY_LABELS = {
    "safe" => "Safe to drive for now",
    "caution" => "Drive with caution",
    "stop" => "Stop driving"
  }.freeze

  DIY_LABELS = {
    "yes" => "Yes, it's a reasonable DIY job",
    "maybe" => "Possible with some experience",
    "no" => "Leave this one to a mechanic"
  }.freeze

  def self.string(description) = { type: "string", description: description }
  def self.enum(values, description) = { type: "string", enum: values, description: description }

  def self.object(properties)
    { type: "object", properties: properties, required: properties.keys.map(&:to_s), additionalProperties: false }
  end

  SCHEMA = object(
    summary: string("The problem in plain words, max 10 words, e.g. 'Squealing from the front wheels when braking'."),
    severity: enum(SEVERITIES, "How serious the problem is."),
    drive_safety: enum(DRIVE_SAFETY, "safe: fine to drive for now; caution: drive gently and get it checked soon; stop: do not drive."),
    safety_note: string("1-2 sentences: what happens if it is ignored, and the warning signs that mean stop driving immediately."),
    causes: {
      type: "array",
      description: "2-4 likely causes, most likely first.",
      items: object(
        name: string("Short name of the cause, e.g. 'Worn brake pads'."),
        likelihood: enum(LIKELIHOODS, "How likely this cause is."),
        detail: string("1-2 sentences on which of the user's symptoms point to it."),
        check: string("A quick check the user can do to confirm or rule it out.")
      )
    },
    diy: object(
      verdict: enum(DIY_VERDICTS, "yes: reasonable DIY job; maybe: possible with experience; no: needs a workshop."),
      difficulty: enum(DIFFICULTIES, "Difficulty of the most likely repair."),
      summary: string("1-2 sentences: the tools and parts needed, or why it is not a DIY job and what to ask the mechanic."),
      steps: { type: "array", items: { type: "string" }, description: "Main steps if it is a reasonable DIY job (max 8), otherwise empty." }
    ),
    costs: {
      type: "array",
      description: "1-5 likely repairs in US dollars, the repair for the most likely cause first.",
      items: object(
        repair: string("What is repaired or replaced, e.g. 'Front brake pads'."),
        low: { type: "integer", description: "Low end of the price range in US dollars." },
        high: { type: "integer", description: "High end of the price range in US dollars." },
        note: string("Short note, e.g. 'parts ~$40, labour ~$110'.")
      )
    },
    cost_note: string("One sentence, e.g. that prices vary by region and shop.")
  )

  # Returns the cleaned report, or nil when the model's output is unusable.
  def self.sanitize(raw, vehicle:)
    return nil unless raw.is_a?(Hash)

    causes = Array(raw["causes"]).first(MAX_CAUSES).filter_map do |cause|
      next unless cause.is_a?(Hash) && text(cause["name"], SHORT_TEXT).present?

      {
        "name" => text(cause["name"], SHORT_TEXT),
        "likelihood" => pick(cause["likelihood"], LIKELIHOODS, "Medium"),
        "detail" => text(cause["detail"], LONG_TEXT),
        "check" => text(cause["check"], LONG_TEXT)
      }
    end

    costs = Array(raw["costs"]).first(MAX_COSTS).filter_map do |cost|
      next unless cost.is_a?(Hash) && text(cost["repair"], SHORT_TEXT).present?

      low, high = [ price(cost["low"]), price(cost["high"]) ].sort
      next if high.zero?

      { "repair" => text(cost["repair"], SHORT_TEXT), "low" => low, "high" => high, "note" => text(cost["note"], SHORT_TEXT) }
    end

    summary = text(raw["summary"], SHORT_TEXT)
    return nil if summary.blank? || causes.empty?

    diy = raw["diy"].is_a?(Hash) ? raw["diy"] : {}
    verdict = pick(diy["verdict"], DIY_VERDICTS, "no")

    {
      "summary" => summary,
      "vehicle" => vehicle,
      "severity" => pick(raw["severity"], SEVERITIES, "Moderate"),
      "drive_safety" => pick(raw["drive_safety"], DRIVE_SAFETY, "caution"),
      "safety_note" => text(raw["safety_note"], LONG_TEXT),
      "causes" => causes,
      "diy" => {
        "verdict" => verdict,
        "difficulty" => pick(diy["difficulty"], DIFFICULTIES, "Workshop only"),
        "summary" => text(diy["summary"], LONG_TEXT),
        "steps" => verdict == "no" ? [] : Array(diy["steps"]).first(MAX_STEPS).map { |s| text(s, SHORT_TEXT * 2) }.compact_blank
      },
      "costs" => costs,
      "cost_note" => text(raw["cost_note"], LONG_TEXT)
    }
  end

  def self.to_markdown(report)
    lines = [ "## Most Likely Causes" ]
    report["causes"].each_with_index do |cause, i|
      lines << "#{i + 1}. **#{cause['name']}** (#{cause['likelihood']}): #{cause['detail']}"
      lines << "   Quick check: #{cause['check']}" if cause["check"].present?
    end

    lines << "" << "## Severity"
    lines << "**#{report['severity']}**. #{DRIVE_SAFETY_LABELS.fetch(report['drive_safety'])}. #{report['safety_note']}".strip

    diy = report["diy"]
    lines << "" << "## Can You Fix This Yourself?"
    lines << "#{DIY_LABELS.fetch(diy['verdict'])}. Difficulty: #{diy['difficulty']}. #{diy['summary']}".strip
    diy["steps"].each_with_index { |step, i| lines << "#{i + 1}. #{step}" }

    lines << "" << "## Estimated Repair Cost"
    report["costs"].each do |cost|
      line = "- #{cost['repair']}: $#{cost['low']}–$#{cost['high']}"
      line += " (#{cost['note']})" if cost["note"].present?
      lines << line
    end
    lines << "" << report["cost_note"] if report["cost_note"].present?

    lines.join("\n")
  end

  def self.text(value, max)
    value.is_a?(String) ? value.squish.truncate(max).presence : nil
  end

  def self.pick(value, allowed, fallback)
    allowed.include?(value) ? value : fallback
  end

  def self.price(value)
    Integer(value, exception: false).to_i.clamp(0, MAX_PRICE)
  end

  private_class_method :string, :enum, :object, :text, :pick, :price
end
