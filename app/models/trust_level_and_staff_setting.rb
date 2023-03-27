# frozen_string_literal: true

class TrustLevelAndStaffSetting < TrustLevelSetting
  def self.valid_value?(val)
    special_group?(val) || (val.to_i.to_s == val.to_s && valid_values.any? { |v| v == val.to_i })
  end

  def self.valid_values
    TrustLevel.valid_range.to_a + special_groups
  end

  def self.special_group?(val)
    special_groups.include?(val.to_s)
  end

  def self.special_groups
    %w[staff admin]
  end

  def self.translation(value)
    if special_group?(value)
      I18n.t("trust_levels.#{value}")
    else
      super
    end
  end
end
