# frozen_string_literal: true

require "enum_site_setting"

class BaseFontSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= DiscourseFonts.fonts.map do |font|
      { name: "base_font_setting.#{font[:key]}", value: font[:key] }
    end
  end

  def self.translate_names?
    true
  end
end
