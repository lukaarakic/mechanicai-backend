module Marketing
  # Generates the data behind dashclue.com's public OBD2 code and car problem
  # pages (mechanicai-frontend app/content/seo/*.json). Seeds live in
  # marketing/seeds/, in publishing order. Entries already in the output file are
  # kept, so a run can be stopped and resumed, and hand edits survive; pass force
  # to regenerate. Each entry gets a publish_on date (see #schedule) and the site
  # shows it from that day, so pages go live in weekly batches on their own.
  class SeoDataset
    KINDS = %w[codes problems].freeze
    SYSTEMS = [
      "Engine", "Fuel and air", "Ignition", "Emissions", "Exhaust", "Cooling", "Transmission",
      "Brakes", "Steering and suspension", "Electrical", "Network and modules", "Climate control"
    ].freeze

    SEEDS_DIR = Rails.root.join("marketing/seeds")
    DEFAULT_OUT_DIR = Rails.root.join("marketing/seo")

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert automotive mechanic with 20+ years of experience writing
      reference pages for DashClue (dashclue.com), read by US drivers who are not
      mechanics. Be accurate and specific, write in plain American English, and give
      prices in US dollars as typical independent-shop prices (parts + labor). Never
      invent statistics, studies, quotes or brand names of shops. If you are not
      sure about something, leave it out rather than guess.
    PROMPT

    def initialize(kind:, out_dir: DEFAULT_OUT_DIR, threads: 4, only: nil, force: false, limit: nil)
      raise ArgumentError, "kind must be one of #{KINDS.join(', ')}" unless KINDS.include?(kind)

      @kind = kind
      @out_path = Pathname(out_dir).join("#{kind}.json")
      @threads = threads.to_i.clamp(1, 16)
      @only = Array(only).map { |s| s.to_s.downcase }.presence
      @force = force
      @limit = limit&.to_i
      @mutex = Mutex.new
    end

    def run
      entries = load_entries
      todo = seeds.reject { |seed| !@force && entries.key?(seed[:id]) }
      todo = todo.select { |seed| @only.include?(seed[:id].downcase) } if @only
      todo = todo.first(@limit) if @limit
      puts "#{@kind}: #{entries.size} already generated, #{todo.size} to go"

      queue = Queue.new
      todo.each { |seed| queue << seed }
      failures = []

      workers = Array.new(@threads) do
        Thread.new do
          while (seed = (queue.pop(true) rescue nil))
            begin
              entry = generate(seed)
              @mutex.synchronize do
                # Regenerating a page keeps its publish date.
                entry&.merge!(entries[seed[:id]]&.slice("publish_on") || {})
                if entry
                  entries[seed[:id]] = entry
                  write(entries)
                  puts "  ok   #{seed[:id]}"
                else
                  puts "  skip #{seed[:id]} (model is not sure this is a standard code)"
                end
              end
            rescue StandardError => e
              @mutex.synchronize do
                failures << seed[:id]
                puts "  FAIL #{seed[:id]}: #{e.class} #{e.message}"
              end
            end
          end
        end
      end
      workers.each(&:join)

      puts "#{@kind}: wrote #{entries.size} entries to #{@out_path}"
      puts "#{@kind}: failed #{failures.join(', ')} (run again to retry)" if failures.any?
      failures.empty?
    end

    # Gives every entry a publish_on date in seed order: the first `first`
    # entries on `start`, then `per_week` more every 7 days. Dates already in the
    # past are kept, so live pages never move. Returns { date => [ids] }.
    def schedule(first:, per_week:, start:)
      entries = load_entries
      today = Date.current
      live, pending = seeds.map { |s| s[:id] }.select { |id| entries[id] }.partition do |id|
        (date = entries[id]["publish_on"]) && Date.parse(date) <= today
      end

      # The launch batch on `start` tops up what is already live; weekly batches
      # follow from a week later, so re-running never adds a batch on `start`.
      launch = pending.shift([ first - live.size, 0 ].max)
      [ launch, *pending.each_slice(per_week) ].each_with_index do |ids, week|
        ids.each { |id| entries[id]["publish_on"] = (start + 7 * week).iso8601 }
      end
      write(entries)
      entries.values.group_by { |e| e["publish_on"] }.sort.to_h.transform_values { |es| es.map { |e| e["code"] || e["slug"] } }
    end

    # Problems found in a generated file, as strings; empty when it is clean.
    def self.check(path)
      return [ "#{path} does not exist" ] unless File.exist?(path)

      entries = JSON.parse(File.read(path))
      key = File.basename(path) == "codes.json" ? "code" : "slug"
      problems = []
      ids = entries.map { |e| e[key] }
      problems << "duplicate ids: #{ids.tally.select { |_, n| n > 1 }.keys.join(', ')}" if ids.uniq.size != ids.size
      entries.group_by { |e| e["title"].to_s.downcase }.each_value do |same|
        problems << "same title on #{same.map { |e| e[key] }.join(', ')}: #{same.first['title']}" if same.size > 1
      end
      entries.each do |e|
        id = e[key]
        %w[title answer meaning severity drive_safety safety_note cost_note].each do |field|
          problems << "#{id}: #{field} is empty" if e[field].blank?
        end
        problems << "#{id}: fewer than 2 causes" if Array(e["causes"]).size < 2
        problems << "#{id}: no costs" if Array(e["costs"]).empty?
        problems << "#{id}: fewer than 3 FAQs" if Array(e["faqs"]).size < 3
        Array(e["costs"]).each do |c|
          problems << "#{id}: cost #{c['repair']} has low > high" if c["low"] > c["high"]
          problems << "#{id}: cost #{c['repair']} is $0" if c["high"].zero?
        end
      end
      problems
    end

    private

    def seeds
      @seeds ||= begin
        lines = File.readlines(SEEDS_DIR.join("#{@kind}.txt")).map(&:strip).reject { |l| l.blank? || l.start_with?("#") }
        seeds = lines.map do |l|
          id, label = l.split("|", 2).map(&:strip)
          if @kind == "codes"
            { id: id.upcase, label: id.upcase, definition: label.presence }
          else
            { id: id.downcase, label: label.presence || id.tr("-", " ") }
          end
        end
        seeds.uniq { |s| s[:id] }
      end
    end

    def code_ids = @kind == "codes" ? seeds.map { |s| s[:id] } : seed_ids("codes")
    def problem_ids = @kind == "problems" ? seeds.map { |s| s[:id] } : seed_ids("problems")

    def seed_ids(kind)
      self.class.new(kind: kind).send(:seeds).map { |s| s[:id] }
    end

    def load_entries
      return {} unless @out_path.exist?

      key = @kind == "codes" ? "code" : "slug"
      JSON.parse(@out_path.read).index_by { |e| e[key] }
    end

    def write(entries)
      FileUtils.mkdir_p(@out_path.dirname)
      sorted = entries.values.sort_by { |e| e["code"] || e["slug"] }
      tmp = "#{@out_path}.tmp"
      File.write(tmp, JSON.pretty_generate(sorted) + "\n")
      File.rename(tmp, @out_path)
    end

    def generate(seed)
      raw = Llm.json(system: SYSTEM_PROMPT, user: prompt_for(seed), name: "seo_#{@kind}", schema: schema)
      return nil if @kind == "codes" && raw["is_standard_code"] != true

      diagnosis = DiagnosisReport.sanitize(raw["diagnosis"], vehicle: nil)
      raise Llm::Error, "unusable diagnosis" if diagnosis.nil?

      faqs = Array(raw["faqs"]).filter_map do |f|
        q, a = f["question"].to_s.squish, f["answer"].to_s.squish
        { "question" => q, "answer" => a } if q.present? && a.present?
      end

      entry = @kind == "codes" ? { "code" => seed[:id] } : { "slug" => seed[:id], "query" => seed[:label] }
      entry.merge(
        "title" => raw["title"].to_s.squish,
        "system" => SYSTEMS.include?(raw["system"]) ? raw["system"] : "Engine",
        "answer" => raw["answer"].to_s.squish,
        "meaning" => raw["meaning"].to_s.squish,
        "symptoms" => Array(raw["symptoms"]).map { |s| s.to_s.squish }.compact_blank.first(8),
        **diagnosis.except("vehicle", "summary"),
        "faqs" => faqs.first(6),
        "related_codes" => (Array(raw["related_codes"]).map(&:upcase) & code_ids - [ seed[:id] ]).first(6),
        "related_problems" => (Array(raw["related_problems"]).map(&:downcase) & problem_ids - [ seed[:id] ]).first(6),
        "generated_at" => Date.current.iso8601
      )
    end

    def prompt_for(seed)
      if @kind == "codes"
        <<~PROMPT
          Write the reference page for OBD2 trouble code #{seed[:label]}.
          #{code_definition(seed)}
          The diagnosis describes the code in general, across common US cars; the
          causes' detail fields say which symptoms or conditions point to each cause.

          related_codes: pick up to 6 closely related codes from this list only:
          #{code_ids.join(' ')}
          related_problems: pick up to 4 related driver problems from this list only:
          #{problem_ids.join(' ')}
        PROMPT
      else
        <<~PROMPT
          Write the reference page for this car problem, as a driver would search it:
          "#{seed[:label]}".
          The diagnosis covers the problem in general, across common US cars; the
          causes' detail fields say which extra symptoms point to each cause.

          related_codes: pick up to 6 OBD2 codes this problem often comes with, from
          this list only (empty if none fit):
          #{code_ids.join(' ')}
          related_problems: pick up to 4 related problems from this list only:
          #{problem_ids.join(' ')}
        PROMPT
      end
    end

    # Seeds carry the SAE definition, so the model writes about the right code
    # instead of recalling the definition (it confuses neighbouring codes).
    def code_definition(seed)
      if seed[:definition]
        <<~TEXT
          Its generic SAE J2012 definition is "#{seed[:definition]}". The page must be
          about exactly this definition. The title is this definition in title case,
          keeping any bank and sensor numbers exactly as given.
          Set is_standard_code to true.
        TEXT
      else
        <<~TEXT
          Use the generic SAE J2012 definition of the code. If #{seed[:label]} is not a
          standard generic code, or it means different things on different makes, set
          is_standard_code to false (the other fields can then be short).
        TEXT
      end
    end

    def schema
      string = ->(description) { { type: "string", description: description } }
      properties = {}
      properties[:is_standard_code] = { type: "boolean", description: "True only if this is a standard generic OBD2 code." } if @kind == "codes"
      properties.merge!(
        title: string.(@kind == "codes" ? "The code's standard definition, e.g. 'Catalyst System Efficiency Below Threshold (Bank 1)'." : "Page heading in title case, e.g. 'Car Shaking When Braking'."),
        system: { type: "string", enum: SYSTEMS, description: "The car system involved." },
        answer: string.("The direct answer in 2 sentences: what it means and the most common fix with its typical cost. Shown first on the page and read by search engines."),
        meaning: string.("3-5 sentences explaining it in plain words: what the part or system does and why the problem happens."),
        symptoms: { type: "array", items: { type: "string" }, description: "3-6 symptoms the driver may notice, short phrases." },
        diagnosis: DiagnosisReport::SCHEMA,
        faqs: {
          type: "array",
          description: "4-5 questions people search about it (e.g. can I drive, cost, can I fix it myself, will it pass inspection), each answered in 1-3 sentences.",
          items: { type: "object", properties: { question: string.("The question."), answer: string.("The answer.") }, required: %w[question answer], additionalProperties: false }
        },
        related_codes: { type: "array", items: { type: "string" }, description: "Codes from the given list only." },
        related_problems: { type: "array", items: { type: "string" }, description: "Problem slugs from the given list only." }
      )
      { type: "object", properties: properties, required: properties.keys.map(&:to_s), additionalProperties: false }
    end
  end
end
