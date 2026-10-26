# frozen_string_literal: true

module WebsiteBrand
  # Counts the colors in a site's icon. SVG icons are read as XML without
  # network access. Raster icons go through the sandboxed ImageMagick, which
  # reduces them to a few colors first, since the edges of a shape blend it
  # into the background.
  module IconColors
    RASTER_FORMATS = { "png" => "\x89PNG".b, "jpeg" => "\xFF\xD8\xFF".b, "gif" => "GIF8".b }.freeze
    SVG_COLOR_ATTRIBUTES = "//@fill | //@stroke | //@stop-color"
    SVG_STYLE_COLOR = /(?:fill|stroke|stop-color)\s*:\s*([^;}"]+)/
    # Partly transparent pixels are mostly anti-aliased edges.
    MIN_ALPHA = 128
    HISTOGRAM_COLORS = 8
    COMMAND_TIMEOUT = 10

    # Returns { "hex" => count } for the opaque colors in an icon file.
    def self.call(body)
      return svg_colors(body) if svg?(body)

      format = raster_format(body)
      format ? raster_colors(body, format) : {}
    end

    def self.svg?(body)
      body.byteslice(0, 512).to_s.scrub("").lstrip.start_with?("<svg", "<?xml")
    end
    private_class_method :svg?

    def self.raster_format(body)
      head = body.byteslice(0, 8).b
      RASTER_FORMATS.find { |_, signature| head.start_with?(signature) }&.first ||
        ("webp" if head.start_with?("RIFF") && body.byteslice(8, 4) == "WEBP")
    end
    private_class_method :raster_format

    def self.svg_colors(body)
      document =
        Nokogiri.XML(body.scrub(""), nil, nil, Nokogiri::XML::ParseOptions::DEFAULT_XML) do |config|
          config.nonet.noblanks
        end
      values = document.xpath(SVG_COLOR_ATTRIBUTES).map(&:value)
      styles = document.xpath("//@style").map(&:value)
      styles += document.xpath("//*[local-name()='style']").map(&:text)
      values += styles.flat_map { |style| style.scan(SVG_STYLE_COLOR).flatten }

      values.filter_map { |value| Color.parse(value) }.tally
    end
    private_class_method :svg_colors

    def self.raster_colors(body, format)
      Tempfile.create(["website-brand-icon", ".#{format}"], binmode: true) do |file|
        file.write(body)
        file.flush

        histogram =
          ImageMagick.magick(
            "#{format}:#{file.path}[0]",
            "-resize",
            "64x64",
            "-colors",
            HISTOGRAM_COLORS.to_s,
            "-depth",
            "8",
            "-format",
            "%c",
            "histogram:info:",
            operation: :website_brand_icon_colors,
            read: [file.path],
            timeout: COMMAND_TIMEOUT,
          )
        parse_histogram(histogram)
      end
    rescue Discourse::Utils::CommandError
      {}
    end
    private_class_method :raster_colors

    # Lines look like `   12: (232,89,12,255) #E8590CFF srgba(...)`.
    def self.parse_histogram(histogram)
      histogram
        .to_s
        .scan(/^\s*(\d+):.*?#(\h{6})(\h{2})?/)
        .each_with_object(Hash.new(0)) do |(count, hex, alpha), colors|
          next if alpha && alpha.to_i(16) < MIN_ALPHA
          colors[hex.downcase] += count.to_i
        end
    end
    private_class_method :parse_histogram
  end
end
