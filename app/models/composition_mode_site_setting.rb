# frozen_string_literal: true

require "enum_site_setting"

class CompositionModeSiteSetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      values.any? { |v| v[:value] == val }
    end

    def values
      @values ||= [
        { name: "composition_mode.markdown", value: 0 },
        { name: "composition_mode.rich", value: 1 },
      ]
    end

    def translate_names?
      true
    end
  end
end
