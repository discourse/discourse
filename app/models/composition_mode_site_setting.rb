# frozen_string_literal: true

require "enum_site_setting"

class CompositionModeSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "composition_mode.markdown", value: 0 },
      { name: "composition_mode.rich", value: 1 },
    ]
  end

  def self.translate_names?
    true
  end
end
