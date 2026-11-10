# frozen_string_literal: true

# Works out the hex value of a palette's CSS color variables, including the
# shades core derives from each base color (--primary-low, --tertiary-hover
# and so on), so contrast checks can resolve them without compiling CSS.
#
# The derivations mirror color_transformations.scss. Values can differ from
# the compiled ones by a step or two per channel, because ColorMath rounds
# hue, saturation and lightness to whole numbers; that is far below what
# changes a contrast check.
module AppearanceStyles
  class PaletteColors
    BASE_NAMES = %w[
      primary
      secondary
      tertiary
      quaternary
      header_background
      header_primary
      highlight
      danger
      success
      love
      selected
      hover
    ].freeze

    # The CSS variable core uses for a base color, where it isn't --<name>.
    BASE_VARIABLES = { "selected" => "--d-selected", "hover" => "--d-hover" }.freeze

    # variable => [color, compared with, lightness, darkness], as
    # dark-light-diff(color, compared with, lightness, darkness).
    DIFFS = {
      "--primary-very-low" => ["primary", "secondary", 0.97, -0.82],
      "--primary-low" => ["primary", "secondary", 0.9, -0.78],
      "--primary-low-mid" => ["primary", "secondary", 0.7, -0.45],
      "--primary-medium" => ["primary", "secondary", 0.5, -0.35],
      "--primary-high" => ["primary", "secondary", 0.3, -0.25],
      "--primary-very-high" => ["primary", "secondary", 0.15, -0.1],
      "--primary-50" => ["primary", "secondary", 0.97, -0.82],
      "--primary-100" => ["primary", "secondary", 0.94, -0.8],
      "--primary-200" => ["primary", "secondary", 0.9, -0.78],
      "--primary-300" => ["primary", "secondary", 0.8, -0.6],
      "--primary-400" => ["primary", "secondary", 0.7, -0.45],
      "--primary-500" => ["primary", "secondary", 0.6, -0.4],
      "--primary-600" => ["primary", "secondary", 0.5, -0.35],
      "--primary-700" => ["primary", "secondary", 0.38, -0.3],
      "--primary-800" => ["primary", "secondary", 0.3, -0.25],
      "--primary-900" => ["primary", "secondary", 0.15, -0.1],
      "--secondary-low" => ["secondary", "primary", 0.7, -0.7],
      "--secondary-medium" => ["secondary", "primary", 0.5, -0.5],
      "--secondary-high" => ["secondary", "primary", 0.3, -0.35],
      "--secondary-very-high" => ["secondary", "primary", 0.07, -0.07],
      "--tertiary-very-low" => ["tertiary", "secondary", 0.9, -0.75],
      "--tertiary-low" => ["tertiary", "secondary", 0.85, -0.65],
      "--tertiary-medium" => ["tertiary", "secondary", 0.5, -0.45],
      "--tertiary-high" => ["tertiary", "secondary", 0.2, -0.25],
      "--tertiary-25" => ["tertiary", "secondary", 0.93, -0.8],
      "--tertiary-50" => ["tertiary", "secondary", 0.9, -0.75],
      "--tertiary-100" => ["tertiary", "secondary", 0.88, -0.72],
      "--tertiary-200" => ["tertiary", "secondary", 0.87, -0.69],
      "--tertiary-300" => ["tertiary", "secondary", 0.85, -0.65],
      "--tertiary-400" => ["tertiary", "secondary", 0.74, -0.58],
      "--tertiary-500" => ["tertiary", "secondary", 0.63, -0.52],
      "--tertiary-600" => ["tertiary", "secondary", 0.5, -0.45],
      "--tertiary-700" => ["tertiary", "secondary", 0.4, -0.38],
      "--tertiary-800" => ["tertiary", "secondary", 0.3, -0.31],
      "--tertiary-900" => ["tertiary", "secondary", 0.2, -0.25],
      "--quaternary-low" => ["quaternary", "secondary", 0.7, -0.7],
      "--highlight-bg" => ["highlight", "secondary", 0.7, -0.8],
      "--highlight-low" => ["highlight", "secondary", 0.7, -0.8],
      "--highlight-medium" => ["highlight", "secondary", 0.5, -0.55],
      "--highlight-high" => ["highlight", "secondary", -0.5, -0.1],
      "--danger-low" => ["danger", "secondary", 0.9, -0.68],
      "--danger-medium" => ["danger", "secondary", 0.3, -0.35],
      "--danger-hover" => ["danger", "secondary", -0.2, -0.2],
      "--success-very-low" => ["success", "secondary", 0.9, -0.7],
      "--success-low" => ["success", "secondary", 0.8, -0.6],
      "--success-medium" => ["success", "secondary", 0.5, -0.4],
      "--success-hover" => ["success", "secondary", -0.2, -0.2],
      "--love-low" => ["love", "secondary", 0.85, -0.6],
      "--d-selected-hover" => ["selected", "secondary", 0.2, 0.2],
    }.freeze

    # variable => percentage of header_primary blended into header_background.
    HEADER_BLENDS = {
      "--header_primary-low" => 10,
      "--header_primary-low-mid" => 35,
      "--header_primary-medium" => 55,
      "--header_primary-high" => 70,
      "--header_primary-very-high" => 90,
    }.freeze

    # variable => [in a light palette, in a dark palette], as dark-light-choose.
    CHOICES = {
      "--primary-med-or-secondary-med" => %w[--primary-medium --secondary-medium],
      "--primary-med-or-secondary-high" => %w[--primary-medium --secondary-high],
      "--primary-high-or-secondary-low" => %w[--primary-high --secondary-low],
      "--primary-low-mid-or-secondary-high" => %w[--primary-low-mid --secondary-high],
      "--primary-low-mid-or-secondary-low" => %w[--primary-low-mid --secondary-low],
      "--primary-or-primary-low-mid" => %w[--primary --primary-low-mid],
      "--highlight-low-or-medium" => %w[--highlight-low --highlight-medium],
      "--tertiary-or-tertiary-low" => %w[--tertiary --tertiary-low],
      "--tertiary-low-or-tertiary-high" => %w[--tertiary-low --tertiary-high],
      "--tertiary-med-or-tertiary" => %w[--tertiary-medium --tertiary],
      "--secondary-or-primary" => %w[--secondary --primary],
    }.freeze

    ALIASES = { "--d-selected-text-color" => "--primary" }.freeze

    # colors: a palette's colors by name ({ "primary" => "222222", ... }).
    # Missing base colors fall back to core's defaults, as they do for a
    # ColorScheme.
    def initialize(colors)
      base = ColorScheme.base_colors.except("hover", "selected").merge(colors.to_h.stringify_keys)
      @named = base.transform_values { |hex| self.class.normalize(hex) }
      @named["hover"] ||= ColorMath.dark_light_diff(primary, secondary, 0.94, -0.78)
      @named["selected"] ||= ColorMath.dark_light_diff(primary, secondary, 0.9, -0.8)
      @cache = {}
    end

    def self.normalize(hex)
      value = hex.to_s.delete_prefix("#").downcase
      value.length == 3 ? value.chars.map { |char| char * 2 }.join : value
    end

    def light?
      ColorMath.brightness(primary) < ColorMath.brightness(secondary)
    end

    # The hex value of a palette variable, or nil when it isn't a palette
    # color this class knows.
    def [](variable)
      return @cache[variable] if @cache.key?(variable)
      @cache[variable] = resolve(variable)
    end

    private

    def primary
      @named["primary"]
    end

    def secondary
      @named["secondary"]
    end

    def resolve(variable)
      if (name = base_name(variable))
        @named[name]
      elsif (alias_of = ALIASES[variable])
        self[alias_of]
      elsif @named.key?(palette_key(variable))
        # a palette may set a derived shade itself
        @named[palette_key(variable)]
      elsif (diff = DIFFS[variable])
        color, compared_with, lightness, darkness = diff
        ColorMath.dark_light_diff(@named[color], @named[compared_with], lightness, darkness)
      elsif (percent = HEADER_BLENDS[variable])
        blend(@named["header_primary"], @named["header_background"], percent)
      elsif (choice = CHOICES[variable])
        self[light? ? choice.first : choice.last]
      end
    end

    def base_name(variable)
      BASE_NAMES.find { |name| (BASE_VARIABLES[name] || "--#{name}") == variable }
    end

    # --primary-low is stored in a palette as primary_low
    def palette_key(variable)
      variable.delete_prefix("--").tr("-", "_")
    end

    # srgb-scale in variables.scss: a blend in approximately linear light.
    def blend(foreground, background, percent)
      ratio = percent / 100.0
      ColorMath::Converters.rgb_to_hex(
        ColorMath::Converters
          .hex_to_rgb(foreground)
          .zip(ColorMath::Converters.hex_to_rgb(background))
          .map { |front, back| Math.sqrt((front**2 * ratio) + (back**2 * (1 - ratio))).round },
      )
    end
  end
end
