# frozen_string_literal: true

module DiscourseAi
  module Agents
    module AppearanceAuthoring
      # Picks the light and dark palettes, out of the ones a theme can already
      # use, that come closest to a brand. The tools use it when a site can't
      # have new palettes. The options are the ones the design wizard offers
      # for the theme: its own palettes, or core's built-in ones.
      class PaletteChoice
        # How much the header and accent colors count, next to the brand color
        # that links and buttons use.
        HEADER_WEIGHT = 0.5
        ACCENT_WEIGHT = 0.3

        Choice =
          Data.define(:name, :light_palette_id, :dark_palette_id, :light_colors, :dark_colors)

        # Returns a Choice, or nil when the theme has no light and dark pair to
        # offer. Colors are six-digit hex.
        def self.closest(theme:, brand:, accent: nil, header: nil)
          DesignWizard::PalettePairs
            .for_theme(theme)
            .filter_map { |pair| choice(pair) }
            .min_by do |choice|
              light = choice.light_colors
              score = distance(brand, light["tertiary"])
              score += HEADER_WEIGHT * distance(header, light["header_background"]) if header
              score += ACCENT_WEIGHT * distance(accent, light["quaternary"]) if accent
              score
            end
        end

        def self.choice(pair)
          return if pair[:light].nil? || pair[:dark].nil?

          Choice.new(
            name: pair[:name],
            light_palette_id: pair[:light][:id],
            dark_palette_id: pair[:dark][:id],
            light_colors: AppearanceAuthoring.normalize_colors(pair[:light][:colors]),
            dark_colors: AppearanceAuthoring.normalize_colors(pair[:dark][:colors]),
          )
        end
        private_class_method :choice

        # How different two colors look: their distance in OKLab.
        def self.distance(hex, other_hex)
          Math.sqrt(oklab(hex).zip(oklab(other_hex)).sum { |value, other| (value - other)**2 })
        end
        private_class_method :distance

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
        private_class_method :oklab
      end
    end
  end
end
