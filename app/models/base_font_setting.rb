# frozen_string_literal: true

require "enum_site_setting"

class BaseFontSetting < EnumSiteSetting

  FONTS = {
    "Helvetica" => { key: :default, font_stack: "Helvetica, Arial, sans-serif" },
    "Open Sans" => { key: :open_sans, font_stack: "Open Sans, Helvetica, Arial, sans-serif" },
    "Oxanium" => { key: :oxanium, font_stack: "Oxanium, Helvetica, Arial, sans-serif" }
  }

  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= FONTS.map do |name, h|
      { name: "base_font_setting.#{h[:key]}", value: name }
    end
  end

  def self.font_stack(font_name)
    FONTS[font_name][:font_stack]
  end

  def self.translate_names?
    true
  end

end
