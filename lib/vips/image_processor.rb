# frozen_string_literal: true

class Vips::ImageProcessor
  PROFILE = Rails.root.join("vendor/data/RT_sRGB.icm").to_s
  UNTRUSTED_FORMATS = %w[jxl svg v vips].freeze
  MAX_PROCESS_SECONDS = 20

  def self.resize(
    from:,
    to:,
    dimensions:,
    source_format:,
    target_format:,
    quality: nil,
    colors: nil
  )
    width, height = parse_box(dimensions)

    with_output(to, target_format:) do |output|
      Vips.call(
        "thumbnail",
        from,
        output_argument(
          output,
          format: target_format,
          quality:,
          colors:,
          strip: SiteSetting.strip_image_metadata,
          profile: PROFILE,
        ),
        width.to_s,
        "--height",
        height.to_s,
        "--size",
        "both",
        "--crop",
        "centre",
        "--output-profile",
        PROFILE,
        read: [from, PROFILE],
        write: [File.dirname(output)],
        timeout: MAX_PROCESS_SECONDS,
        nice: 10,
        allow_untrusted: untrusted_format?(source_format) || untrusted_format?(target_format),
      )
    end
  end

  def self.crop(from:, to:, dimensions:, source_format:, target_format:, quality: nil, colors: nil)
    width, height = parse_box(dimensions)
    source_width, source_height = dimensions(from, format: source_format, auto_orient: true)
    scale = [width.fdiv(source_width), height.fdiv(source_height)].max
    cover_width = (source_width * scale).ceil
    cover_height = (source_height * scale).ceil

    Dir.mktmpdir("vips-crop") do |directory|
      intermediate = File.join(directory, "cover.v")

      Vips.call(
        "thumbnail",
        from,
        intermediate,
        cover_width.to_s,
        "--height",
        cover_height.to_s,
        "--size",
        "both",
        "--output-profile",
        PROFILE,
        read: [from, PROFILE],
        write: [directory],
        timeout: MAX_PROCESS_SECONDS,
        nice: 10,
        allow_untrusted: untrusted_format?(source_format),
      )

      with_output(to, target_format:) do |output|
        Vips.call(
          "gravity",
          intermediate,
          output_argument(
            output,
            format: target_format,
            quality:,
            colors:,
            strip: SiteSetting.strip_image_metadata,
            profile: PROFILE,
          ),
          "north",
          width.to_s,
          height.to_s,
          "--extend",
          "background",
          "--background",
          "0 0 0 0",
          read: [intermediate, PROFILE],
          write: [File.dirname(output)],
          timeout: MAX_PROCESS_SECONDS,
          nice: 10,
          allow_untrusted: true,
        )
      end
    end
  end

  def self.downsize(
    from:,
    to:,
    dimensions:,
    source_format:,
    target_format:,
    quality: nil,
    colors: nil
  )
    width, height, size = downsize_box(path: from, geometry: dimensions, source_format:)

    with_output(to, target_format:) do |output|
      Vips.call(
        "thumbnail",
        from,
        output_argument(
          output,
          format: target_format,
          quality:,
          colors:,
          strip: SiteSetting.strip_image_metadata,
          profile: PROFILE,
        ),
        width.to_s,
        "--height",
        height.to_s,
        "--size",
        size,
        "--output-profile",
        PROFILE,
        read: [from, PROFILE],
        write: [File.dirname(output)],
        timeout: MAX_PROCESS_SECONDS,
        nice: 10,
        allow_untrusted: untrusted_format?(source_format) || untrusted_format?(target_format),
      )
    end
  end

  def self.convert(
    from:,
    to:,
    source_format:,
    target_format:,
    flatten:,
    quality: nil,
    failure_message: ""
  )
    Dir.mktmpdir("vips-convert") do |directory|
      upright = File.join(directory, "upright.v")

      Vips.call(
        "autorot",
        from,
        upright,
        read: [from],
        write: [directory],
        timeout: MAX_PROCESS_SECONDS,
        allow_untrusted: untrusted_format?(source_format),
        failure_message:,
      )

      with_output(to, target_format:) do |output|
        operation = flatten ? "flatten" : "copy"
        arguments = [
          upright,
          output_argument(output, format: target_format, quality:, strip: false),
        ]
        arguments.concat(%w[--background 255]) if flatten

        Vips.call(
          operation,
          *arguments,
          read: [upright],
          write: [File.dirname(output)],
          timeout: MAX_PROCESS_SECONDS,
          allow_untrusted: true,
          failure_message:,
        )
      end
    end
  end

  def self.autorot(path:, format:, quality: nil, timeout: MAX_PROCESS_SECONDS)
    with_output(path, target_format: format) do |output|
      Vips.call(
        "autorot",
        path,
        output_argument(output, format:, quality:, strip: false),
        read: [path],
        write: [File.dirname(output)],
        timeout:,
        allow_untrusted: untrusted_format?(format),
      )
    end
  end

  def self.dimensions(path, format: nil, auto_orient: false)
    format ||= File.extname(path).delete_prefix(".")
    if format.casecmp?("svg")
      width, height = svg_dimensions(path)
    else
      allow_untrusted = untrusted_format?(format)
      width =
        Vips.header(
          path,
          field: "width",
          timeout: Upload::MAX_IDENTIFY_SECONDS,
          allow_untrusted:,
        ).to_i
      height =
        Vips.header(
          path,
          field: "height",
          timeout: Upload::MAX_IDENTIFY_SECONDS,
          allow_untrusted:,
        ).to_i
    end

    if auto_orient && rotated?(path, format:)
      [height, width]
    else
      [width, height]
    end
  end

  def self.frame_count(path, format: nil)
    format ||= File.extname(path).delete_prefix(".")
    Vips.header(
      path,
      field: "n-pages",
      timeout: Upload::MAX_IDENTIFY_SECONDS,
      allow_untrusted: untrusted_format?(format),
    ).to_i
  rescue Discourse::Utils::CommandError
    1
  end

  def self.rotated?(path, format: nil)
    format ||= File.extname(path).delete_prefix(".")
    orientation =
      Vips.header(
        path,
        field: "orientation",
        timeout: Upload::MAX_IDENTIFY_SECONDS,
        allow_untrusted: untrusted_format?(format),
      ).to_i
    (5..8).cover?(orientation)
  rescue Discourse::Utils::CommandError
    false
  end

  def self.svg_dimensions(path)
    document = Nokogiri.XML(File.binread(path)) { |config| config.strict.nonet }
    root = document.root
    raise Discourse::InvalidAccess if root.nil? || root.name != "svg"

    vips_width = svg_header(path, field: "width")
    vips_height = svg_header(path, field: "height")
    view_box = root["viewBox"].to_s.split.map { |value| Float(value, exception: false) }

    [
      svg_dimension(value: root["width"], vips_value: vips_width, view_box_value: view_box[2]),
      svg_dimension(value: root["height"], vips_value: vips_height, view_box_value: view_box[3]),
    ]
  end

  def self.svg_header(path, field:)
    Vips.header(path, field:, timeout: Upload::MAX_IDENTIFY_SECONDS, allow_untrusted: true).to_i
  rescue Discourse::Utils::CommandError
    0
  end
  private_class_method :svg_header

  def self.svg_dimension(value:, vips_value:, view_box_value:)
    match = value.to_s.strip.match(/\A([+-]?(?:\d+(?:\.\d*)?|\.\d+))(.*)\z/)
    return vips_value if match.nil?

    number = match[1].to_f
    unit = match[2].strip.downcase
    return view_box_value.to_f.round if number.zero? && view_box_value.to_f.positive?

    pixels =
      case unit
      when "in"
        number * 96
      when "cm"
        number * 96 / 2.54
      when "mm"
        number * 96 / 25.4
      when "q"
        number * 96 / 101.6
      when "pt"
        number * 96 / 72
      when "pc"
        number * 16
      when "%"
        view_box_value.to_f * number / 100
      else
        return vips_value
      end
    pixels.round
  end
  private_class_method :svg_dimension

  def self.downsize_box(path:, geometry:, source_format:)
    width, height = dimensions(path, format: source_format, auto_orient: true)

    case geometry
    when /\A(\d+(?:\.\d+)?)%\z/
      scale = Regexp.last_match(1).to_f / 100
      [[(width * scale).round, 1].max, [(height * scale).round, 1].max, "both"]
    when /\A(\d+)@\z/
      scale = Math.sqrt(Regexp.last_match(1).to_f / (width * height))
      [[(width * scale).round, 1].max, [(height * scale).round, 1].max, "both"]
    when /\A(\d+)x(\d+)>?\z/
      [
        Regexp.last_match(1).to_i,
        Regexp.last_match(2).to_i,
        geometry.end_with?(">") ? "down" : "both",
      ]
    else
      raise ArgumentError, "Unsupported image geometry: #{geometry}"
    end
  end
  private_class_method :downsize_box

  def self.parse_box(dimensions)
    match = dimensions.match(/\A(\d+)x(\d+)\z/)
    raise ArgumentError, "Unsupported image geometry: #{dimensions}" if match.nil?
    [match[1].to_i, match[2].to_i]
  end
  private_class_method :parse_box

  def self.output_argument(path, format:, quality: nil, colors: nil, strip:, profile: nil)
    format = format.to_s.downcase
    options = []
    options << "strip=true" if strip
    options << "profile=#{profile}" if profile
    options << "Q=#{quality}" if quality && %w[avif heic heif jpeg jpg jxl webp].include?(format)
    if colors && format == "png"
      options << "palette=true"
      options << "colours=#{colors}"
    elsif colors && format == "gif"
      options << "bitdepth=#{Math.log2(colors).ceil.clamp(1, 8)}"
    end
    options.empty? ? path : "#{path}[#{options.join(",")}]"
  end
  private_class_method :output_argument

  def self.with_output(path, target_format:)
    directory = File.dirname(path)
    extension = ".#{target_format}"

    Dir.mktmpdir("vips-output", directory) do |temporary_directory|
      output = File.join(temporary_directory, "image#{extension}")
      yield output
      if !File.file?(output)
        raise Discourse::Utils::CommandError, "vips did not create #{target_format} output"
      end
      if File.exist?(path)
        File.open(output, "rb") do |source|
          File.open(path, "wb") { |target| IO.copy_stream(source, target) }
        end
      else
        FileUtils.mv(output, path)
      end
    end
  end
  private_class_method :with_output

  def self.untrusted_format?(format)
    UNTRUSTED_FORMATS.include?(format.to_s.downcase)
  end
  private_class_method :untrusted_format?

  private_constant :PROFILE, :UNTRUSTED_FORMATS, :MAX_PROCESS_SECONDS
end
