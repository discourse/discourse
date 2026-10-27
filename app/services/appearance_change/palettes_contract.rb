# frozen_string_literal: true

# Parameters for the services that save appearance changes with new palettes:
# the shared ones, plus the colors of a light and a dark palette.
class AppearanceChange::PalettesContract < AppearanceChange::Contract
  HEX_COLOR = /\A\h{6}\z/

  PALETTE =
    proc do
      ColorScheme.base_colors.each_key { |color_name| attribute color_name, :string }

      validates(*ColorScheme.base_colors.keys, presence: true, format: { with: HEX_COLOR })
    end

  attribute :light_colors, :hash, &PALETTE
  attribute :dark_colors, :hash, &PALETTE

  validates :light_colors, :dark_colors, presence: true

  def light_palette_colors
    palette_colors(light_colors)
  end

  def dark_palette_colors
    palette_colors(dark_colors)
  end

  def dark_palette_name
    AppearanceChange.dark_palette_name(name)
  end

  private

  def palette_colors(palette)
    palette.to_hash.map { |color_name, hex| { name: color_name.to_s, hex: hex.downcase } }
  end
end
