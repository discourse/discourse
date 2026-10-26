# frozen_string_literal: true

# Parameters shared by the services that save appearance changes: a name, a
# light and a dark palette, and the fonts to use once the change is live.
class AppearanceChange::Contract < Service::ContractBase
  HEX_COLOR = /\A\h{6}\z/

  PALETTE =
    proc do
      ColorScheme.base_colors.each_key { |color_name| attribute color_name, :string }

      validates(*ColorScheme.base_colors.keys, presence: true, format: { with: HEX_COLOR })
    end

  attribute :name, :string
  attribute :light_colors, :hash, &PALETTE
  attribute :dark_colors, :hash, &PALETTE
  attribute :site_settings, :hash, default: -> { {} } do
    attribute :base_font, :string
    attribute :heading_font, :string

    validates :base_font,
              :heading_font,
              inclusion: {
                in: BaseFontSetting.values.map { |font| font[:value] },
              },
              allow_blank: true
  end

  validates :name, presence: true, length: { maximum: 100 }
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

  def site_settings_to_apply
    (site_settings&.to_hash || {}).compact_blank.stringify_keys
  end

  private

  def palette_colors(palette)
    palette.to_hash.map { |color_name, hex| { name: color_name.to_s, hex: hex.downcase } }
  end
end
