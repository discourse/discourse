# frozen_string_literal: true

require "enum_site_setting"

class BaseFontSetting < EnumSiteSetting

  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= [
      { name: 'base_font_setting.default', value: 'Helvetica' },
      { name: 'base_font_setting.oxanium', value: 'Oxanium' }
    ]
  end

  def self.translate_names?
    true
  end

end
