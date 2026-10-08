module Marketing
  # Writes a short-form video script (TikTok, Shorts, Reels) about one car
  # problem. The script carries a full DiagnosisReport so the causes and prices
  # said in the video match what DashClue says in the app.
  class TiktokScript
    FORMATS = {
      "symptom" => "\"If your car does this...\": show the symptom, then the top 2-3 causes and what each costs to fix.",
      "quote_check" => "\"Is this quote a rip-off?\": start from a typical shop quote for the repair (say it is an example), then the fair price range and what to ask the shop.",
      "code_of_the_day" => "\"Check engine code of the day\": what the code means, the most likely cause, the cost, and whether you can keep driving.",
      "live_diagnosis" => "Screen recording of DashClue diagnosing a viewer's problem: read the viewer's problem, show the questions DashClue asks, react to the result.",
      "stop_driving" => "\"Stop driving if...\": the warning signs of this problem that mean pull over now, and the ones that can wait."
    }.freeze

    SCHEMA = {
      type: "object",
      properties: {
        diagnosis: DiagnosisReport::SCHEMA,
        title: { type: "string", description: "Internal working title, max 8 words." },
        hook: { type: "string", description: "First 2 seconds, said and shown on screen. Max 12 words. Creates curiosity or urgency." },
        beats: {
          type: "array",
          description: "5-6 beats covering the whole video, 30-40 seconds in total.",
          items: {
            type: "object",
            properties: {
              time: { type: "string", description: "e.g. '0-2s'." },
              on_screen: { type: "string", description: "Text overlay, max 8 words." },
              voiceover: { type: "string", description: "What is said in this beat." },
              footage: { type: "string", description: "Stock-video search phrase for this beat's background, 2-4 plain English words that a stock site has footage of, e.g. 'brake disc close up', 'car dashboard warning light', 'mechanic under car', 'highway driving'. No brands or text." }
            },
            required: %w[time on_screen voiceover footage],
            additionalProperties: false
          }
        },
        caption: { type: "string", description: "Post caption, 1-2 sentences, ends with a question that invites comments." },
        hashtags: { type: "array", items: { type: "string" }, description: "3-5 hashtags without spaces, e.g. #cartok." },
        cta: { type: "string", description: "Closing call to action pointing to dashclue.com (or the link in bio)." }
      },
      required: %w[diagnosis title hook beats caption hashtags cta],
      additionalProperties: false
    }.freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert automotive mechanic with 20+ years of experience who also
      writes short-form videos for DashClue (dashclue.com), a web app where drivers
      describe a car problem and get the likely causes, how serious it is, whether
      it's safe to drive, DIY steps and a US-dollar repair cost range.

      Audience: US drivers who aren't mechanics, watching on TikTok, YouTube Shorts
      and Instagram Reels. Write in plain, spoken American English.

      Rules:
      - Fill the diagnosis first, as an honest mechanic would for this car and
        symptom; the video must only use causes and prices from it. Prices in USD.
      - 60-85 spoken words in total (30-40 seconds), 5-6 beats. No intros like "Hey guys". The first beat is
        the hook: its voiceover says the hook and it must work with the sound off.
      - The video is made from stock footage, so every beat's footage must be
        something generic a stock site has (car parts, dashboards, roads,
        mechanics), never a screen recording or a specific person.
      - Write voiceover for text-to-speech: spell out prices as words a voice reads
        naturally ("about two hundred fifty dollars"), no symbols or abbreviations.
      - Never invent testimonials, reviews, customer stories, statistics or real
        shop names, and never present an example quote or receipt as a real one.
      - Be honest about safety. Don't say DashClue replaces a mechanic; it helps
        you understand the problem before you go to one.
      - Mention DashClue at most twice, in the last beats and the call to action.
    PROMPT

    attr_reader :symptom, :car, :format

    def initialize(symptom:, car: nil, format: "symptom")
      raise ArgumentError, "unknown format #{format.inspect}; use one of #{FORMATS.keys.join(', ')}" unless FORMATS.key?(format)

      @symptom = symptom.to_s.squish
      @car = car.to_s.squish.presence
      @format = format
      raise ArgumentError, "symptom is required" if @symptom.blank?
    end

    def generate
      raw = Llm.json(system: SYSTEM_PROMPT, user: user_prompt, name: "tiktok_script", schema: SCHEMA)
      diagnosis = DiagnosisReport.sanitize(raw["diagnosis"], vehicle: car || "Typical US car")
      raise Llm::Error, "the model returned an unusable diagnosis" if diagnosis.nil?

      raw.merge("diagnosis" => diagnosis)
    end

    def to_markdown(script)
      lines = [ "# #{script['title']}", "" ]
      lines << "- **Format:** #{format}"
      lines << "- **Problem:** #{symptom}"
      lines << "- **Car:** #{car || 'any (generic)'}"
      lines << "" << "## Hook" << "" << script["hook"].to_s
      lines << "" << "## Shot list" << ""
      lines << "| Time | On screen | Voiceover | Footage |"
      lines << "| --- | --- | --- | --- |"
      Array(script["beats"]).each do |beat|
        cells = beat.values_at("time", "on_screen", "voiceover", "footage").map { |c| c.to_s.gsub("|", "/").squish }
        lines << "| #{cells.join(' | ')} |"
      end
      lines << "" << "## Caption" << "" << "#{script['caption']} #{Array(script['hashtags']).join(' ')}".strip
      lines << "" << "## CTA" << "" << script["cta"].to_s
      lines << "" << "## Facts behind the video" << ""
      lines << DiagnosisReport.to_markdown(script["diagnosis"])
      lines.join("\n") + "\n"
    end

    private

    def user_prompt
      <<~PROMPT
        Format: #{FORMATS.fetch(format)}
        Car problem: #{symptom}
        Car: #{car || 'not specified; keep it generic and use typical US prices for a common sedan or SUV'}
      PROMPT
    end
  end
end
