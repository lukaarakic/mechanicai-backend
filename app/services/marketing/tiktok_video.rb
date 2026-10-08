require "open3"
require "net/http"

module Marketing
  # Turns a TiktokScript into a finished 1080x1920 MP4: an AI voiceover per beat,
  # a Pexels stock clip behind each beat (a dark card when there is no key or no
  # match), and captions burned in with the brand fonts. Needs ffmpeg on PATH.
  class TiktokVideo
    class Error < StandardError; end

    WIDTH = 1080
    HEIGHT = 1920
    FPS = 30
    FONTS_DIR = Rails.root.join("marketing/assets/fonts")
    CLIP_CACHE = Rails.root.join("marketing/tiktok/.cache")
    VOICE = ENV.fetch("TIKTOK_VOICE", "ash")
    VOICE_STYLE = "Energetic, confident American guy explaining a car problem to a friend on TikTok. " \
                  "Quick pace, natural, no announcer voice."
    # Words per caption on screen at once.
    CAPTION_WORDS = 3

    def self.ffmpeg_available?
      system("ffmpeg -version > /dev/null 2>&1") && system("ffprobe -version > /dev/null 2>&1")
    end

    def initialize(script, dir:)
      @script = script
      @dir = Pathname(dir)
      @work = @dir.join("work")
      @used_clips = []
    end

    # Renders and returns the path to video.mp4.
    def render
      raise Error, "ffmpeg is not installed (in the API container: apt-get install -y ffmpeg)" unless self.class.ffmpeg_available?

      FileUtils.mkdir_p(@work)
      beats = Array(@script["beats"]).select { |b| b["voiceover"].to_s.strip.present? }
      raise Error, "the script has no beats with voiceover" if beats.empty?

      timeline = beats.each_with_index.map do |beat, i|
        audio = @work.join(format("voice-%02d.mp3", i))
        File.binwrite(audio, Llm.speech(beat["voiceover"], voice: VOICE, instructions: VOICE_STYLE))
        duration = probe_duration(audio)
        segment = @work.join(format("segment-%02d.mp4", i))
        render_segment(find_clip(beat["footage"]), duration, segment)
        { beat: beat, audio: audio, segment: segment, duration: duration }
      end

      video = @dir.join("video.mp4")
      mux(timeline, video)
      video
    ensure
      FileUtils.rm_rf(@work) if video&.exist?
    end

    private

    # --- Stock footage -------------------------------------------------------

    def find_clip(query)
      return nil if ENV["PEXELS_API_KEY"].blank?

      [ query, "car repair", "car driving" ].compact_blank.each do |q|
        video = search_pexels(q).find { |v| !@used_clips.include?(v["id"]) }
        next unless video

        file = pick_file(video)
        next unless file

        @used_clips << video["id"]
        return download_clip(video["id"], file["link"])
      end
      nil
    rescue StandardError => e
      Rails.logger.warn("Pexels lookup failed for #{query.inspect}: #{e.message}")
      nil
    end

    def search_pexels(query)
      uri = URI("https://api.pexels.com/videos/search")
      uri.query = URI.encode_www_form(query: query, orientation: "portrait", size: "medium", per_page: 8)
      response = http_get(uri, "Authorization" => ENV.fetch("PEXELS_API_KEY"))
      raise Error, "Pexels returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("videos", [])
    end

    # The smallest file that still fills a 1080x1920 frame well.
    def pick_file(video)
      files = Array(video["video_files"]).select { |f| f["file_type"] == "video/mp4" && f["width"].to_i >= 720 }
      files.min_by { |f| [ f["height"].to_i < 1280 ? 1 : 0, f["width"].to_i * f["height"].to_i ] }
    end

    def download_clip(id, link)
      FileUtils.mkdir_p(CLIP_CACHE)
      path = CLIP_CACHE.join("pexels-#{id}.mp4")
      return path if path.exist? && path.size.positive?

      response = http_get(URI(link))
      raise Error, "clip download returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      File.binwrite(path, response.body)
      path
    end

    def http_get(uri, headers = {}, redirects = 3)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 120) do |http|
        request = Net::HTTP::Get.new(uri)
        headers.each { |k, v| request[k] = v }
        http.request(request)
      end
      if response.is_a?(Net::HTTPRedirection) && redirects.positive?
        return http_get(URI.join(uri.to_s, response["location"]), {}, redirects - 1)
      end

      response
    end

    # --- Rendering -----------------------------------------------------------

    # One beat's background: the clip looped or cut to the voice's length,
    # cropped to portrait and darkened so captions stay readable.
    def render_segment(clip, duration, out)
      input = clip ? [ "-stream_loop", "-1", "-i", clip.to_s ] : [ "-f", "lavfi", "-i", "color=c=0x080808:s=#{WIDTH}x#{HEIGHT}:r=#{FPS}" ]
      filter = "scale=#{WIDTH}:#{HEIGHT}:force_original_aspect_ratio=increase,crop=#{WIDTH}:#{HEIGHT}," \
               "fps=#{FPS},eq=brightness=-0.12:saturation=1.1,format=yuv420p"
      run("ffmpeg", "-y", *input, "-t", format("%.3f", duration), "-vf", filter, "-an",
          "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", out.to_s)
    end

    def mux(timeline, out)
      list = @work.join("segments.txt")
      File.write(list, timeline.map { |t| "file '#{t[:segment]}'" }.join("\n"))
      run("ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list.to_s, "-c", "copy", @work.join("video.mp4").to_s)

      audio_list = @work.join("voice.txt")
      File.write(audio_list, timeline.map { |t| "file '#{t[:audio]}'" }.join("\n"))
      run("ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", audio_list.to_s, "-c:a", "aac", "-b:a", "160k", @work.join("voice.m4a").to_s)

      subtitles = @work.join("captions.ass")
      File.write(subtitles, captions(timeline))
      run("ffmpeg", "-y", "-i", @work.join("video.mp4").to_s, "-i", @work.join("voice.m4a").to_s,
          "-vf", "ass=#{subtitles}:fontsdir=#{FONTS_DIR}", "-c:v", "libx264", "-preset", "medium", "-crf", "20",
          "-c:a", "copy", "-shortest", "-movflags", "+faststart", out.to_s)
    end

    # ASS subtitles: the beat's headline at the top, the voiceover in 3-word
    # chunks that pop in mid-screen, and the domain near the bottom. Positions
    # stay inside TikTok's safe area (its UI covers the bottom ~25% and right
    # edge). Word timing is estimated from word length within each beat.
    def captions(timeline)
      lines = [ <<~ASS ]
        [Script Info]
        ScriptType: v4.00+
        PlayResX: #{WIDTH}
        PlayResY: #{HEIGHT}
        WrapStyle: 0

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Headline,Anton,108,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,0,0,0,0,100,100,1,0,1,6,0,8,90,150,330,1
        Style: Caption,Anton,118,&H0000E5FF,&H0000E5FF,&H00000000,&H64000000,0,0,0,0,100,100,1,0,1,8,0,5,90,150,0,1
        Style: Brand,Inter,46,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,3,0,2,90,150,520,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
      ASS

      clock = 0.0
      timeline.each do |t|
        start = clock
        finish = clock + t[:duration]
        headline = ass_text(t[:beat]["on_screen"]).upcase
        lines << dialogue(start, finish, "Headline", headline) if headline.present?

        chunks = caption_chunks(t[:beat]["voiceover"])
        total = chunks.sum { |c| c.length + 2 }.to_f
        at = start
        chunks.each do |chunk|
          length = t[:duration] * (chunk.length + 2) / total
          pop = "{\\fscx85\\fscy85\\t(0,90,\\fscx100\\fscy100)}"
          lines << dialogue(at, at + length, "Caption", pop + ass_text(chunk).sub(/[.,;:]+\z/, "").upcase)
          at += length
        end
        clock = finish
      end
      lines << dialogue(0, clock, "Brand", "dashclue.com")
      lines.join("\n") + "\n"
    end

    # Splits voiceover into short chunks, ending a chunk at punctuation.
    def caption_chunks(text)
      chunks = []
      current = []
      text.to_s.split.each do |word|
        current << word
        if current.size >= CAPTION_WORDS || word.match?(/[.,!?;:]\z/)
          chunks << current.join(" ")
          current = []
        end
      end
      chunks << current.join(" ") if current.any?
      chunks
    end

    def dialogue(from, to, style, text)
      "Dialogue: 0,#{ass_time(from)},#{ass_time(to)},#{style},,0,0,0,,#{text}"
    end

    def ass_time(seconds)
      cs = (seconds * 100).round
      format("%d:%02d:%02d.%02d", cs / 360_000, (cs / 6000) % 60, (cs / 100) % 60, cs % 100)
    end

    # Model text can't inject ASS override tags or line breaks.
    def ass_text(text)
      text.to_s.gsub(/[{}\\]/, "").squish
    end

    def probe_duration(path)
      out = run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path.to_s)
      Float(out.strip)
    end

    def run(*command)
      stdout, stderr, status = Open3.capture3(*command)
      raise Error, "#{command.first} failed: #{stderr.lines.last(5).join.strip}" unless status.success?

      stdout
    end
  end
end
