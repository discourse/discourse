# frozen_string_literal: true

class TrustLevelSetting < EnumSiteSetting
  def self.valid_value?(val)
    val.to_i.to_s == val.to_s && valid_values.any? { |v| v == val.to_i }
  end

  def self.values
    valid_values.map { |value| { name: translation(value), value: value } }
  end

  def self.valid_values
    TrustLevel.valid_range.to_a
  end

  def self.translation(value)
    I18n.t("js.trust_levels.detailed_name", level: value, name: TrustLevel.name(value))
  end

  private_class_method :valid_values
  private_class_method :translation
end
