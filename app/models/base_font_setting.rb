# frozen_string_literal: true

require "enum_site_setting"

class BaseFontSetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      values.any? { |v| v[:value].to_s == val.to_s }
    end

    def values
      @values ||= DiscourseFonts.fonts.map { |font| { name: font[:name], value: font[:key] } }
    end
  end
end
