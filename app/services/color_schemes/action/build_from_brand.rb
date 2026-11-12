# frozen_string_literal: true

# Builds a light and a dark palette from a brand color, with an optional
# accent and header color, so a site can take on a brand's look and stay
# readable. The brand color becomes the link and button color.
#
# A color that would leave text below the WCAG AA contrast ratio is moved in
# lightness, keeping its hue, until the text reads. Each move is reported, so
# whatever shows the palettes can explain why a color differs from the one
# that was asked for.
class ColorSchemes::Action::BuildFromBrand < Service::ActionBase
  HEX_COLOR = /\A#?(?:\h{3}|\h{6})\z/
  MINIMUM_CONTRAST = 4.5

  # The text and background pairs both palettes keep readable. Primary buttons
  # put secondary text on a tertiary background, which the link pair covers.
  READABLE_PAIRS = [
    %w[primary secondary],
    %w[tertiary secondary],
    %w[header_primary header_background],
    %w[primary selected],
    %w[primary hover],
  ].freeze

  # These keep core's colors: the status colors signal states rather than a
  # brand, and quaternary is only replaced when an accent is given.
  CORE_COLOR_NAMES = %w[quaternary highlight danger success love].freeze

  # Black and white text have the same contrast on a background of this
  # luminance, so it decides which way a color has to move.
  MIDPOINT_LUMINANCE = Math.sqrt(1.05 * 0.05) - 0.05

  # Below this saturation, in percent, a brand color counts as grey, so text
  # and backgrounds derived from it stay neutral instead of being tinted.
  GREY_SATURATION = 10
  TINT_SATURATION = 12

  WHITE = "ffffff"

  Adjustment = Data.define(:mode, :name, :from, :to, :against)
  Result = Data.define(:light, :dark, :adjustments)

  option :brand
  option :accent, optional: true
  option :header, optional: true

  def call
    @adjustments = []
    Result.new(light: light_palette, dark: dark_palette, adjustments: @adjustments)
  end

  private

  def light_palette
    primary = shade(13)
    secondary = WHITE
    tertiary = readable(:light, "tertiary", brand_color, against: secondary)
    header_background, header_primary =
      if header_color
        readable_header(:light, header_color, text_colors: [WHITE, primary])
      else
        [secondary, primary]
      end

    core_colors(ColorScheme.base_colors).merge(
      "primary" => primary,
      "secondary" => secondary,
      "tertiary" => tertiary,
      "header_background" => header_background,
      "header_primary" => header_primary,
      "selected" => tint(tertiary, 92),
      "hover" => tint(tertiary, 96),
    )
  end

  def dark_palette
    primary = shade(90)
    secondary = shade(11)
    tertiary = readable(:dark, "tertiary", brand_color, against: secondary)
    # a dark header keeps the brand's hue without glaring in dark mode
    header = header_color ? at_most_lightness(header_color, 16) : shade(8)
    header_background, header_primary =
      readable_header(:dark, header, text_colors: [primary, secondary])

    core_colors(ColorScheme::BUILT_IN_SCHEMES[:Dark]).merge(
      "primary" => primary,
      "secondary" => secondary,
      "tertiary" => tertiary,
      "header_background" => header_background,
      "header_primary" => header_primary,
      "selected" => tint(tertiary, 20),
      "hover" => tint(secondary, 18),
    )
  end

  # Picks whichever text color reads best on the header, then moves the
  # header color if even that text isn't readable.
  def readable_header(mode, color, text_colors:)
    text = text_colors.max_by { |candidate| ColorMath.contrast_ratio(candidate, color) }
    [readable(mode, "header_background", color, against: text), text]
  end

  # Moves a color's lightness away from the color it's read against until the
  # pair is readable. Black or white always is, so the loop ends by then.
  def readable(mode, name, color, against:)
    return color if readable_pair?(color, against)

    hue, saturation, lightness = hsl(color)
    step = ColorMath.relative_luminance(against) > MIDPOINT_LUMINANCE ? -1 : 1
    adjusted = color
    while !readable_pair?(adjusted, against) && (lightness + step).between?(0, 100)
      lightness += step
      adjusted = hex(hue, saturation, lightness)
    end

    @adjustments << Adjustment.new(mode:, name:, from: color, to: adjusted, against:)
    adjusted
  end

  def readable_pair?(color, other_color)
    ColorMath.contrast_ratio(color, other_color) >= MINIMUM_CONTRAST
  end

  def shade(lightness)
    hue, saturation, = hsl(brand_color)
    hex(hue, saturation < GREY_SATURATION ? 0 : TINT_SATURATION, lightness)
  end

  def tint(color, lightness)
    hue, saturation, = hsl(color)
    hex(hue, [saturation, 60].min, lightness)
  end

  def at_most_lightness(color, lightness)
    hue, saturation, current = hsl(color)
    hex(hue, saturation, [current, lightness].min)
  end

  def core_colors(source)
    colors = source.slice(*CORE_COLOR_NAMES).transform_values { |color| normalize(color) }
    colors["quaternary"] = accent_color if accent_color
    colors
  end

  def brand_color
    @brand_color ||= normalize(brand)
  end

  def accent_color
    @accent_color ||= normalize(accent) if accent.present?
  end

  def header_color
    @header_color ||= normalize(header) if header.present?
  end

  def normalize(color)
    raise ArgumentError, "#{color.inspect} is not a hex color" if !HEX_COLOR.match?(color.to_s)

    value = color.to_s.delete_prefix("#").downcase
    value.length == 3 ? value.gsub(/(.)/, '\1\1') : value
  end

  def hsl(color)
    ColorMath::Converters.rgb_to_hsl(*ColorMath::Converters.hex_to_rgb(color))
  end

  def hex(hue, saturation, lightness)
    ColorMath::Converters.rgb_to_hex(ColorMath::Converters.hsl_to_rgb(hue, saturation, lightness))
  end
end
