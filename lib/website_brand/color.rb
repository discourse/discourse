# frozen_string_literal: true

module WebsiteBrand
  # Turns CSS color values into six-digit hex, and measures colors in OKLab,
  # where the distance between two colors follows how different they look.
  module Color
    HEX = /\A#(\h{3,4}|\h{6}|\h{8})\z/
    FUNCTION = /\A([a-z-]+)\((.*)\)\z/m
    NAMED = { "white" => "ffffff", "black" => "000000" }.freeze
    # Where a color can start inside a longer value, such as a gradient.
    CANDIDATE =
      /#\h{3,8}\b|\b(?:rgba?|hsla?|oklab|oklch|lab|lch|color|light-dark)\(|\b(?:white|black)\b/

    # Colors this transparent say little about a brand.
    MIN_ALPHA = 0.9
    MAX_COLOR_LENGTH = 300
    MAX_VALUE_LENGTH = 2_000

    # OKLab thresholds: below this chroma a color reads as grey, and colors
    # lighter or darker than these read as white or black.
    NEUTRAL_CHROMA = 0.04
    MIN_VIVID_LIGHTNESS = 0.1
    MAX_VIVID_LIGHTNESS = 0.97

    # CSS lab() and lch() use the D50 white point.
    D50_WHITE = [0.96422, 1.0, 0.82521].freeze

    # Returns six-digit lowercase hex, or nil when the value isn't an opaque
    # color. `variables` resolves `var()` references.
    def self.parse(value, variables = {})
      return if value.to_s.length > MAX_VALUE_LENGTH

      value =
        CssValue.substitute_variables(value.to_s.strip, variables, max_length: MAX_COLOR_LENGTH)
      return if value.blank?

      value = value.downcase

      value = value.delete_suffix("!important").strip
      return from_hex(value[HEX, 1]) if value.match?(HEX)
      return NAMED[value] if NAMED.key?(value)

      name, arguments = value.match(FUNCTION)&.captures
      return if name.nil?

      case name
      when "rgb", "rgba"
        from_rgb(channels(arguments))
      when "hsl", "hsla"
        from_hsl(channels(arguments))
      when "lab", "oklab"
        from_lab(name, channels(arguments))
      when "lch", "oklch"
        from_lch(name, channels(arguments))
      when "color"
        from_color_function(channels(arguments))
      when "light-dark"
        parse(CssValue.split_arguments(arguments).first)
      end
    end

    # The first color in a value that can hold several, such as a
    # `background` shorthand or a gradient.
    def self.first_in(value, variables = {})
      return if value.to_s.length > MAX_VALUE_LENGTH

      value =
        CssValue.substitute_variables(value.to_s, variables, max_length: MAX_VALUE_LENGTH)&.downcase
      return if value.nil?

      position = 0
      while (match = CANDIDATE.match(value, position))
        finish = match.end(0)
        if match[0].end_with?("(")
          finish = CssValue.closing_parenthesis(value, finish - 1)
          return if finish.nil?
          finish += 1
        end

        color = parse(value[match.begin(0)...finish])
        return color if color
        position = finish
      end
    end

    def self.oklab(hex)
      red, green, blue =
        hex
          .scan(/../)
          .map do |pair|
            channel = pair.to_i(16) / 255.0
            channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
          end
      long = Math.cbrt((0.4122214708 * red) + (0.5363325363 * green) + (0.0514459929 * blue))
      medium = Math.cbrt((0.2119034982 * red) + (0.6806995451 * green) + (0.1073969566 * blue))
      short = Math.cbrt((0.0883024619 * red) + (0.2817188376 * green) + (0.6299787005 * blue))

      [
        (0.2104542553 * long) + (0.7936177850 * medium) - (0.0040720468 * short),
        (1.9779984951 * long) - (2.4285922050 * medium) + (0.4505937099 * short),
        (0.0259040371 * long) + (0.7827717662 * medium) - (0.8086757660 * short),
      ]
    end

    def self.lightness(hex)
      oklab(hex)[0]
    end

    def self.chroma(hex)
      Math.hypot(*oklab(hex)[1, 2])
    end

    def self.hue(hex)
      _, a, b = oklab(hex)
      (Math.atan2(b, a) * 180 / Math::PI) % 360
    end

    def self.hue_difference(hex, other_hex)
      (((hue(hex) - hue(other_hex) + 180) % 360) - 180).abs
    end

    def self.distance(hex, other_hex)
      Math.sqrt(oklab(hex).zip(oklab(other_hex)).sum { |value, other| (value - other)**2 })
    end

    def self.neutral?(hex)
      chroma(hex) < NEUTRAL_CHROMA
    end

    # Whether a color can carry a brand: neither grey, nor nearly white or
    # black.
    def self.vivid?(hex)
      !neutral?(hex) && lightness(hex).between?(MIN_VIVID_LIGHTNESS, MAX_VIVID_LIGHTNESS)
    end

    # Channels in either the comma or the space and slash syntax. The alpha
    # channel, when there is one, comes fourth.
    def self.channels(arguments)
      arguments.to_s.split(%r{[\s,/]+}).reject(&:empty?)
    end
    private_class_method :channels

    def self.from_hex(digits)
      digits = digits.chars.map { |digit| digit * 2 }.join if digits.length <= 4
      return if digits.length == 8 && digits[6, 2].to_i(16) / 255.0 < MIN_ALPHA

      digits[0, 6]
    end
    private_class_method :from_hex

    def self.from_rgb(channels)
      return if !usable?(channels)

      channels.first(3).map { |channel| hex_byte(number(channel, percent_of: 255) / 255.0) }.join
    end
    private_class_method :from_rgb

    def self.from_hsl(channels)
      return if !usable?(channels)

      hue = angle(channels[0])
      saturation = channels[1].to_f / 100
      lightness = channels[2].to_f / 100
      chroma = (1 - ((2 * lightness) - 1).abs) * saturation
      second = chroma * (1 - (((hue / 60.0) % 2) - 1).abs)
      red, green, blue =
        case hue % 360
        when 0...60
          [chroma, second, 0]
        when 60...120
          [second, chroma, 0]
        when 120...180
          [0, chroma, second]
        when 180...240
          [0, second, chroma]
        when 240...300
          [second, 0, chroma]
        else
          [chroma, 0, second]
        end
      offset = lightness - (chroma / 2)
      [red, green, blue].map { |channel| hex_byte(channel + offset) }.join
    end
    private_class_method :from_hsl

    def self.from_lab(name, channels)
      return if !usable?(channels)

      if name == "oklab"
        from_oklab(
          number(channels[0], percent_of: 1),
          number(channels[1], percent_of: 0.4),
          number(channels[2], percent_of: 0.4),
        )
      else
        from_cie_lab(
          number(channels[0], percent_of: 100),
          number(channels[1], percent_of: 125),
          number(channels[2], percent_of: 125),
        )
      end
    end
    private_class_method :from_lab

    def self.from_lch(name, channels)
      return if !usable?(channels)

      hue = angle(channels[2]) * Math::PI / 180
      if name == "oklch"
        chroma = number(channels[1], percent_of: 0.4)
        from_oklab(
          number(channels[0], percent_of: 1),
          chroma * Math.cos(hue),
          chroma * Math.sin(hue),
        )
      else
        chroma = number(channels[1], percent_of: 150)
        from_cie_lab(
          number(channels[0], percent_of: 100),
          chroma * Math.cos(hue),
          chroma * Math.sin(hue),
        )
      end
    end
    private_class_method :from_lch

    # display-p3 is read as sRGB: close enough to tell which color a brand
    # uses, and colors outside sRGB couldn't be shown on a palette anyway.
    def self.from_color_function(channels)
      space = channels.shift
      return if !%w[srgb srgb-linear display-p3].include?(space) || !usable?(channels)

      values = channels.first(3).map { |channel| number(channel, percent_of: 1) }
      return values.map { |value| hex_byte(value) }.join if space != "srgb-linear"

      encode_linear_rgb(values)
    end
    private_class_method :from_color_function

    def self.from_oklab(lightness, a, b)
      long = (lightness + (0.3963377774 * a) + (0.2158037573 * b))**3
      medium = (lightness - (0.1055613458 * a) - (0.0638541728 * b))**3
      short = (lightness - (0.0894841775 * a) - (1.2914855480 * b))**3

      encode_linear_rgb(
        [
          (4.0767416621 * long) - (3.3077115913 * medium) + (0.2309699292 * short),
          (-1.2684380046 * long) + (2.6097574011 * medium) - (0.3413193965 * short),
          (-0.0041960863 * long) - (0.7034186147 * medium) + (1.7076147010 * short),
        ],
      )
    end
    private_class_method :from_oklab

    def self.from_cie_lab(lightness, a, b)
      fy = (lightness + 16) / 116.0
      fx = fy + (a / 500.0)
      fz = fy - (b / 200.0)
      inverse = ->(value) { value**3 > 0.008856 ? value**3 : ((116 * value) - 16) / 903.3 }
      x = inverse.(fx) * D50_WHITE[0]
      y = lightness > 8 ? fy**3 : lightness / 903.3
      z = inverse.(fz) * D50_WHITE[2]

      # Bradford adaptation from D50 to D65, then XYZ to linear sRGB.
      x65 = (0.9554734527 * x) - (0.0230985368 * y) + (0.0632593086 * z)
      y65 = (-0.0283697093 * x) + (1.0099954580 * y) + (0.0210413989 * z)
      z65 = (0.0123140016 * x) - (0.0205076964 * y) + (1.3303659366 * z)

      encode_linear_rgb(
        [
          (3.2404542 * x65) - (1.5371385 * y65) - (0.4985314 * z65),
          (-0.9692660 * x65) + (1.8760108 * y65) + (0.0415560 * z65),
          (0.0556434 * x65) - (0.2040259 * y65) + (1.0572252 * z65),
        ],
      )
    end
    private_class_method :from_cie_lab

    def self.encode_linear_rgb(channels)
      channels
        .map do |channel|
          channel = channel.clamp(0.0, 1.0)
          channel <= 0.0031308 ? 12.92 * channel : (1.055 * (channel**(1 / 2.4))) - 0.055
        end
        .map { |channel| hex_byte(channel) }
        .join
    end
    private_class_method :encode_linear_rgb

    def self.usable?(channels)
      channels.size >= 3 && (channels[3].nil? || number(channels[3], percent_of: 1) >= MIN_ALPHA)
    end
    private_class_method :usable?

    # `none` counts as zero. A percentage is a share of `percent_of`.
    def self.number(channel, percent_of:)
      return 0.0 if channel == "none"
      return channel.to_f / 100 * percent_of if channel.end_with?("%")

      channel.to_f
    end
    private_class_method :number

    def self.angle(channel)
      value = channel.to_f
      case channel
      when /turn\z/
        value * 360
      when /grad\z/
        value * 0.9
      when /rad\z/
        value * 180 / Math::PI
      else
        value
      end
    end
    private_class_method :angle

    def self.hex_byte(fraction)
      format("%02x", (fraction.to_f.clamp(0.0, 1.0) * 255).round)
    end
    private_class_method :hex_byte
  end
end
