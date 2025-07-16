# frozen_string_literal: true

class MergeLightAndDarkPalettes < ActiveRecord::Migration[7.2]
  def up
    change_column_null :color_scheme_colors, :hex, true

    [
      ["WCAG", "WCAG Dark", "WCAG"],
      ["Solarized Light", "Solarized Dark", "Solarized"],
    ].each do |(light_scheme_name, dark_scheme_name, merged_name)|
      possible_light_schemes = DB.query_hash(<<~SQL, light_scheme_name:)
        SELECT id
        FROM color_schemes
        WHERE base_scheme_id = :light_scheme_name
        ORDER BY id ASC
      SQL
      possible_dark_schemes = DB.query_hash(<<~SQL, dark_scheme_name:)
        SELECT id
        FROM color_schemes
        WHERE base_scheme_id = :dark_scheme_name
        ORDER BY id ASC
      SQL

      next if possible_light_schemes.size == 0 || possible_dark_schemes.size == 0

      light_schemes =
        possible_light_schemes.select do |scheme|
          colors_unchanged?(scheme["id"], COLORS_MAP[light_scheme_name])
        end
      dark_schemes =
        possible_dark_schemes.select do |scheme|
          colors_unchanged?(scheme["id"], COLORS_MAP[dark_scheme_name])
        end

      next if light_schemes.size == 0 || dark_schemes.size == 0

      min_count = [light_schemes.size, dark_schemes.size].min
      min_count.times do |i|
        light_scheme_id = light_schemes[i]["id"]
        dark_scheme_id = dark_schemes[i]["id"]

        merge_palettes(
          light_scheme_id,
          COLORS_MAP[light_scheme_name].merge(ADDITIONAL_COLORS[light_scheme_name] || {}),
          COLORS_MAP[dark_scheme_name].merge(ADDITIONAL_COLORS[dark_scheme_name] || {}),
        )

        DB.exec(<<~SQL, dark_scheme_id:)
          DELETE FROM color_scheme_colors
          WHERE color_scheme_id = :dark_scheme_id
        SQL
        DB.exec(<<~SQL, dark_scheme_id:)
          DELETE FROM color_schemes
          WHERE id = :dark_scheme_id
        SQL
        DB.exec(<<~SQL, light_scheme_id:, merged_name:)
          UPDATE color_schemes
          SET name = :merged_name, updated_at = NOW()
          WHERE id = :light_scheme_id AND name != :merged_name
        SQL
        DB.exec(<<~SQL, light_scheme_id:, dark_scheme_id:)
          UPDATE themes
          SET color_scheme_id = :light_scheme_id, updated_at = NOW()
          WHERE color_scheme_id = :dark_scheme_id
        SQL
        DB.exec(<<~SQL, dark_scheme_id: dark_scheme_id.to_s)
          UPDATE site_settings
          SET value = '-1'
          WHERE name = 'default_dark_mode_color_scheme_id' AND value = :dark_scheme_id
        SQL
      end
    end

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
    palettes.each { |palette| properly_classify_as_dark_palette(palette) }
  end

  def down
  end

  private

  def colors_unchanged?(palette_id, colors_map)
    color_tuples =
      colors_map.map { |name, hex| "('#{name.downcase}', '#{hex.downcase}')" }.join(", ")

    DB.query_single(<<~SQL, palette_id:).first
      WITH color_tuples(name, hex) AS (
        VALUES #{color_tuples}
      )

      SELECT
        NOT EXISTS (
          SELECT * FROM color_tuples
          EXCEPT
          SELECT LOWER(name), LOWER(hex)
          FROM color_scheme_colors
          WHERE color_scheme_id = :palette_id
        )
        AND
        NOT EXISTS (
          SELECT LOWER(name), LOWER(hex)
          FROM color_scheme_colors
          WHERE color_scheme_id = :palette_id
          EXCEPT
          SELECT * FROM color_tuples
        )
    SQL
  end

  def merge_palettes(light_scheme_id, light_colors_map, dark_colors_map)
    light_colors_map.each do |name, hex|
      dark_hex = dark_colors_map[name]
      count =
        DB.exec(<<~SQL, color_scheme_id: light_scheme_id, name: name, hex: hex, dark_hex: dark_hex)
        UPDATE color_scheme_colors
        SET hex = :hex, dark_hex = :dark_hex, updated_at = NOW()
        WHERE color_scheme_id = :color_scheme_id AND name = :name
      SQL

      if count == 0
        DB.exec(<<~SQL, color_scheme_id: light_scheme_id, name: name, hex: hex, dark_hex: dark_hex)
          INSERT INTO color_scheme_colors (color_scheme_id, name, hex, dark_hex, created_at, updated_at)
          VALUES (:color_scheme_id, :name, :hex, :dark_hex, NOW(), NOW())
        SQL
      end
    end
  end

  def properly_classify_as_dark_palette(palette)
    id = palette["color_scheme_id"]
    colors = palette["colors"]

    return if colors.any? { |color| color["dark_hex"].present? }

    DB.exec(<<~SQL, id:) if is_dark_palette?(colors)
        UPDATE color_scheme_colors
        SET dark_hex = hex, hex = NULL, updated_at = NOW()
        WHERE color_scheme_id = :id
      SQL
  end

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

  COLORS_MAP = {
    "WCAG" => {
      "primary" => "000000",
      "primary-medium" => "696969",
      "primary-low-mid" => "909090",
      "secondary" => "ffffff",
      "tertiary" => "0033cc",
      "quaternary" => "3369ff",
      "header_background" => "ffffff",
      "header_primary" => "000000",
      "highlight" => "ffff00",
      "highlight-high" => "0036e6",
      "highlight-medium" => "e0e9ff",
      "highlight-low" => "e0e9ff",
      "selected" => "e2e9fe",
      "hover" => "f0f4fe",
      "danger" => "bb1122",
      "success" => "3d854d",
      "love" => "9d256b",
    },
    "WCAG Dark" => {
      "primary" => "ffffff",
      "primary-medium" => "999999",
      "primary-low-mid" => "888888",
      "secondary" => "0c0c0c",
      "tertiary" => "759aff",
      "quaternary" => "759aff",
      "header_background" => "000000",
      "header_primary" => "ffffff",
      "highlight" => "3369ff",
      "selected" => "0d2569",
      "hover" => "002382",
      "danger" => "ff697a",
      "success" => "70b880",
      "love" => "9d256b",
    },
    "Solarized Light" => {
      "primary_very_low" => "f0ecd7",
      "primary_low" => "d6d8c7",
      "primary_low_mid" => "a4afa5",
      "primary_medium" => "7e918c",
      "primary_high" => "4c6869",
      "primary" => "002b36",
      "primary-50" => "f0ebda",
      "primary-100" => "dad8ca",
      "primary-200" => "b2b9b3",
      "primary-300" => "839496",
      "primary-400" => "76898c",
      "primary-500" => "697f83",
      "primary-600" => "627a7e",
      "primary-700" => "556f74",
      "primary-800" => "415f66",
      "primary-900" => "21454e",
      "secondary_low" => "325458",
      "secondary_medium" => "6c8280",
      "secondary_high" => "97a59d",
      "secondary_very_high" => "e8e6d3",
      "secondary" => "fcf6e1",
      "tertiary_low" => "d6e6de",
      "tertiary_medium" => "7ebfd7",
      "tertiary" => "0088cc",
      "tertiary_high" => "329ed0",
      "quaternary" => "e45735",
      "header_background" => "fcf6e1",
      "header_primary" => "002b36",
      "highlight_low" => "fdf9ad",
      "highlight_medium" => "e3d0a3",
      "highlight" => "f2f481",
      "highlight_high" => "bcaa7f",
      "selected" => "e8e6d3",
      "hover" => "f0ebda",
      "danger_low" => "f8d9c2",
      "danger" => "e45735",
      "success_low" => "cfe5b9",
      "success_medium" => "4cb544",
      "success" => "009900",
      "love_low" => "fcddd2",
      "love" => "fa6c8d",
    },
    "Solarized Dark" => {
      "primary_very_low" => "0d353f",
      "primary_low" => "193f47",
      "primary_low_mid" => "798c88",
      "primary_medium" => "97a59d",
      "primary_high" => "b5bdb1",
      "primary" => "fcf6e1",
      "primary-50" => "21454e",
      "primary-100" => "415f66",
      "primary-200" => "556f74",
      "primary-300" => "627a7e",
      "primary-400" => "697f83",
      "primary-500" => "76898c",
      "primary-600" => "839496",
      "primary-700" => "b2b9b3",
      "primary-800" => "dad8ca",
      "primary-900" => "f0ebda",
      "secondary_low" => "b5bdb1",
      "secondary_medium" => "81938d",
      "secondary_high" => "4e6a6b",
      "secondary_very_high" => "143b44",
      "secondary" => "002b36",
      "tertiary_low" => "003e54",
      "tertiary_medium" => "00557a",
      "tertiary" => "1a97d5",
      "tertiary_high" => "006c9f",
      "quaternary_low" => "944835",
      "quaternary" => "e45735",
      "header_background" => "002b36",
      "header_primary" => "fcf6e1",
      "highlight_low" => "4d6b3d",
      "highlight_medium" => "464c33",
      "highlight" => "f2f481",
      "highlight_high" => "bfca47",
      "selected" => "143b44",
      "hover" => "21454e",
      "danger_low" => "443836",
      "danger_medium" => "944835",
      "danger" => "e45735",
      "success_low" => "004c26",
      "success_medium" => "007313",
      "success" => "009900",
      "love_low" => "4b3f50",
      "love" => "fa6c8d",
    },
  }

  ADDITIONAL_COLORS = {
    "WCAG Dark" => {
      "highlight-high" => "1453ff",
      "highlight-medium" => "00248a",
      "highlight-low" => "00103d",
    },
    "Solarized Light" => {
      "quaternary_low" => "f7cdc2",
      "danger_medium" => "ec8972",
    },
  }
end
