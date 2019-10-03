# frozen_string_literal: true

class ReviewableSensitivitySetting < EnumSiteSetting

  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    Reviewable.sensitivity.map do |p|
      { name: I18n.t("reviewables.sensitivity.#{p[0]}"), value: p[1] }
    end
  end

  def self.translate_names?
    false
  end

end
