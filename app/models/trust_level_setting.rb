# frozen_string_literal: true

class TrustLevelSetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      val.to_i.to_s == val.to_s && valid_values.any? { |v| v == val.to_i }
    end

    def values
      valid_values.map { |value| { name: translation(value), value: value } }
    end

    def valid_values
      TrustLevel.valid_range.to_a
    end

    def translation(value)
      I18n.t("js.trust_levels.detailed_name", level: value, name: TrustLevel.name(value))
    end
  end

  private_class_method :valid_values
  private_class_method :translation
end
