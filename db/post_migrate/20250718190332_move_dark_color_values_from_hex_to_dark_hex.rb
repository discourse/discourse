# frozen_string_literal: true

class MoveDarkColorValuesFromHexToDarkHex < ActiveRecord::Migration[7.2]
  def up
    palettes = DB.query_hash(<<~SQL)
      SELECT
        color_scheme_id,
        jsonb_agg(
          jsonb_build_object(
            'name',
            name,
            'hex',
            hex,
            'dark_hex',
            dark_hex
          )
        ) AS colors
      FROM color_scheme_colors
      GROUP BY color_scheme_id
    SQL
    palettes.each do |palette|
      colors = palette["colors"]
      next if colors.any? { |color| color["dark_hex"].present? }
      next if !is_dark_palette?(colors)

      id = palette["color_scheme_id"]
      DB.exec(<<~SQL, id:)
        UPDATE color_scheme_colors
        SET dark_hex = hex, hex = NULL, updated_at = NOW()
        WHERE color_scheme_id = :id
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def is_dark_palette?(colors)
    primary = colors.find { |c| c["name"] == "primary" }&.[]("hex")
    secondary = colors.find { |c| c["name"] == "secondary" }&.[]("hex")

    return false if !primary || !secondary

    primary = primary.gsub(/(.)/, '\1\1') if primary.size == 3
    secondary = secondary.gsub(/(.)/, '\1\1') if secondary.size == 3

    return false if primary.size != 6 || secondary.size != 6

    primary_brightness = brightness(hex_to_rgb(primary))
    secondary_brightness = brightness(hex_to_rgb(secondary))

    primary_brightness > secondary_brightness
  end

  def hex_to_rgb(color)
    color.scan(/../).map { |c| c.to_i(16) }
  end

  # copied from lib/color_math.rb
  def brightness(rgb)
    (rgb[0].to_i * 299 + rgb[1].to_i * 587 + rgb[2].to_i * 114) / 1000.0
  end
end
