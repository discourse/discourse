# frozen_string_literal: true

class LetterAvatar
  class Identity
    attr_accessor :color, :letter

    def self.from_username(username)
      identity = new
      identity.color = Digest::MD5.hexdigest(username)[0...15].to_i(16) % 360
      identity.letter = username[0].upcase
      identity
    end
  end

  # BUMP UP if avatar algorithm changes
  VERSION = 6

  # CHANGE these values to support more pixel ratios
  FULLSIZE = 120 * 3
  POINTSIZE = 200

  # oklch color generation parameters — tune these for brightness/vibrancy tradeoffs
  LIGHTNESS = 0.60
  CHROMA = 0.25

  class << self
    def version
      "#{VERSION}_#{image_magick_version}"
    end

    def cache_path
      "tmp/letter_avatars/#{version}"
    end

    def generate(username, size, opts = nil)
      DistributedMutex.synchronize("letter_avatar_#{version}_#{username}") do
        identity = (opts && opts[:identity]) || LetterAvatar::Identity.from_username(username)

        cache = true
        cache = false if opts && opts[:cache] == false

        size = FULLSIZE if size > FULLSIZE
        filename = cached_path(identity, size)

        return filename if cache && File.exist?(filename)

        fullsize = fullsize_path(identity)
        generate_fullsize(identity) if !cache || !File.exist?(fullsize)

        # Optimizing here is dubious, it can save up to 2x for large images (eg 359px)
        # BUT... we are talking 2400 bytes down to 1200 bytes, both fit in one packet
        # The cost of this is huge, its a 40% perf hit
        OptimizedImage.resize(fullsize, filename, size, size)

        filename
      end
    end

    def cached_path(identity, size)
      dir = "#{cache_path}/#{identity.letter}/#{identity.color}"
      FileUtils.mkdir_p(dir)
      File.expand_path "#{dir}/#{size}.png"
    end

    def fullsize_path(identity)
      File.expand_path cached_path(identity, FULLSIZE)
    end

    def generate_fullsize(identity)
      r, g, b = oklch_to_rgb(LIGHTNESS, CHROMA, identity.color)
      letter = identity.letter

      filename = fullsize_path(identity)

      instructions = %W[
        -size
        #{FULLSIZE}x#{FULLSIZE}
        xc:rgb(#{r},#{g},#{b})
        -pointsize
        #{POINTSIZE}
        -fill
        #FFFFFF
        -font
        Inter-Bold
        -gravity
        Center
        -annotate
        -0+34
        #{letter}
        -depth
        8
        #{filename}
      ]

      Discourse::Utils.execute_command("magick", *instructions)

      ## do not optimize image, it will end up larger than original
      filename
    end

    def oklch_to_rgb(lightness, chroma, hue_degrees)
      h = hue_degrees * Math::PI / 180.0
      a = chroma * Math.cos(h)
      b = chroma * Math.sin(h)

      l_ = lightness + 0.3963377774 * a + 0.2158037573 * b
      m_ = lightness - 0.1055613458 * a - 0.0638541728 * b
      s_ = lightness - 0.0894841775 * a - 1.2914855480 * b

      l3 = l_**3
      m3 = m_**3
      s3 = s_**3

      r_lin = (+4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3).clamp(0.0, 1.0)
      g_lin = (-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3).clamp(0.0, 1.0)
      b_lin = (-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3).clamp(0.0, 1.0)

      [
        (srgb_gamma(r_lin) * 255).round,
        (srgb_gamma(g_lin) * 255).round,
        (srgb_gamma(b_lin) * 255).round,
      ]
    end

    def srgb_gamma(x)
      x <= 0.0031308 ? 12.92 * x : 1.055 * (x**(1.0 / 2.4)) - 0.055
    end

    def image_magick_version
      @image_magick_version ||=
        begin
          Thread.new do
            sleep 2
            cleanup_old
          end
          Digest::MD5.hexdigest(`magick --version` << `magick -list font`)
        end
    end

    def cleanup_old
      begin
        skip = File.basename(cache_path)
        parent_path = File.dirname(cache_path)
        Dir
          .entries(parent_path)
          .each do |path|
            FileUtils.rm_rf(parent_path + "/" + path) unless %w[. ..].include?(path) || path == skip
          end
      rescue Errno::ENOENT
        # no worries, folder doesn't exists
      end
    end
  end
end
