# frozen_string_literal: true

class ImageQualitySetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      values.any? { |v| v[:value].to_s == val.to_s }
    end

    def values
      [
        { name: "original", value: 100 },
        { name: "high", value: 90 },
        { name: "medium", value: 70 },
        { name: "low", value: 50 },
      ]
    end

    def translate_names?
      false
    end
  end
end
