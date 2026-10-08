# Content generators for marketing. They call OpenAI with the Pro model and
# write files only; nothing touches the database. The TikTok tasks render a
# finished video per script (needs ffmpeg, and PEXELS_API_KEY for stock
# footage; SCRIPT_ONLY=1 skips the video). Run them locally, e.g.:
#
#   docker exec mechanicai_api bundle exec rake "marketing:tiktok[car shaking when braking,2015 Honda Civic,symptom]"
#   docker exec mechanicai_api bundle exec rake "marketing:tiktok_batch[marketing/seeds/tiktok.txt]"
#   docker exec mechanicai_api bundle exec rake marketing:seo_dataset            # codes + problems
#   docker exec mechanicai_api bundle exec rake "marketing:seo_dataset[codes,P0420 P0171]"
#   docker exec mechanicai_api bundle exec rake marketing:seo_check
#   docker exec mechanicai_api bundle exec rake "marketing:seo_schedule[codes,20,12]"  # launch 20, then 12 a week
#
# Env: THREADS (default 4), FORCE=1 to regenerate existing SEO entries,
# LIMIT=n to generate only the first n missing entries, OUT=dir for the SEO JSON.
namespace :marketing do
  # One folder per video: video.mp4 to upload, caption.txt to paste, script.md.
  write_tiktok = lambda do |generator, index: nil|
    script = generator.generate
    name = [ index && format("%02d", index), generator.format, generator.symptom.parameterize.first(50) ].compact.join("-")
    dir = Rails.root.join("marketing/tiktok", Date.current.iso8601, name)
    FileUtils.mkdir_p(dir)
    File.write(dir.join("script.md"), generator.to_markdown(script))
    File.write(dir.join("caption.txt"), "#{script['caption']} #{Array(script['hashtags']).join(' ')}".strip + "\n")
    Marketing::TiktokVideo.new(script, dir: dir).render unless ENV["SCRIPT_ONLY"] == "1"
    puts "  wrote #{dir.relative_path_from(Rails.root)}/"
  end

  desc "Make one short video (script, caption, MP4): marketing:tiktok[symptom,car,format]"
  task :tiktok, [ :symptom, :car, :format ] => :environment do |_, args|
    generator = Marketing::TiktokScript.new(symptom: args[:symptom], car: args[:car], format: args[:format].presence || "symptom")
    write_tiktok.call(generator)
  end

  desc "Make a video per line of a file (symptom | car | format; car and format optional)"
  task :tiktok_batch, [ :file ] => :environment do |_, args|
    path = args[:file].presence || "marketing/seeds/tiktok.txt"
    lines = File.readlines(Rails.root.join(path)).map(&:strip).reject { |l| l.blank? || l.start_with?("#") }
    formats = Marketing::TiktokScript::FORMATS.keys
    lines.each_with_index do |line, i|
      symptom, car, format = line.split("|").map(&:strip)
      generator = Marketing::TiktokScript.new(symptom: symptom, car: car, format: format.presence || formats[i % formats.size])
      write_tiktok.call(generator, index: i + 1)
    rescue StandardError => e
      puts "  FAIL line #{i + 1} (#{symptom}): #{e.class} #{e.message}"
    end
  end

  desc "Generate the SEO page data: marketing:seo_dataset[kind,ids] (kind: codes, problems or both)"
  task :seo_dataset, [ :kind, :ids ] => :environment do |_, args|
    kinds = args[:kind].presence ? [ args[:kind] ] : Marketing::SeoDataset::KINDS
    options = {
      threads: ENV.fetch("THREADS", 4),
      only: args[:ids].to_s.split.presence,
      force: ENV["FORCE"] == "1",
      limit: ENV["LIMIT"].presence,
      out_dir: ENV["OUT"].presence || Marketing::SeoDataset::DEFAULT_OUT_DIR
    }
    ok = kinds.map { |kind| Marketing::SeoDataset.new(kind: kind, **options).run }.all?
    abort "Some entries failed; run the task again to retry them." unless ok
  end

  desc "Set publish dates: marketing:seo_schedule[kind,first,per_week,start] (start defaults to today)"
  task :seo_schedule, [ :kind, :first, :per_week, :start ] => :environment do |_, args|
    abort "Usage: rake \"marketing:seo_schedule[codes,20,12]\"" unless args[:kind].present? && args[:per_week].to_i.positive?

    dataset = Marketing::SeoDataset.new(kind: args[:kind], out_dir: ENV["OUT"].presence || Marketing::SeoDataset::DEFAULT_OUT_DIR)
    start = args[:start].present? ? Date.parse(args[:start]) : Date.current
    plan = dataset.schedule(first: args[:first].to_i, per_week: args[:per_week].to_i, start: start)
    plan.each { |date, ids| puts "#{date}: #{ids.size} (#{ids.first(4).join(', ')}#{ids.size > 4 ? ', ...' : ''})" }
    puts "Copy marketing/seo/*.json to the frontend's app/content/seo/ and deploy once; pages then go live on their dates."
  end

  desc "Check the generated SEO JSON for missing fields, duplicates and bad prices"
  task seo_check: :environment do
    dir = Pathname(ENV["OUT"].presence || Marketing::SeoDataset::DEFAULT_OUT_DIR)
    problems = Marketing::SeoDataset::KINDS.flat_map { |kind| Marketing::SeoDataset.check(dir.join("#{kind}.json")) }
    if problems.empty?
      puts "SEO data looks good."
    else
      puts problems
      abort "#{problems.size} problems found."
    end
  end
end
