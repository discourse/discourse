# frozen_string_literal: true

class TrustLevelAndStaffAndDisabledSetting < TrustLevelAndStaffSetting
  class << self
    def valid_value?(val)
      valid_values.include?(val) || (val.to_i.to_s == val.to_s && valid_values.include?(val.to_i))
    end

    def valid_values
      ["disabled"] + TrustLevel.valid_range.to_a + special_groups
    end

    def translation(value)
      if value == "disabled"
        I18n.t("site_settings.disabled")
      else
        super
      end
    end

    def matches?(value, user)
      case value
      when "disabled"
        false
      when "staff"
        user.staff?
      when "admin"
        user.admin?
      else
        user.has_trust_level?(value.to_i) || user.staff?
      end
    end
  end
end
