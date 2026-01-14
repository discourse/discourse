# frozen_string_literal: true

class ImageQualitySetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    [
      { name: "original", value: 100 },
      { name: "high", value: 90 },
      { name: "medium", value: 70 },
      { name: "low", value: 50 },
    ]
  end

  def self.translate_names?
    false
  end
end
