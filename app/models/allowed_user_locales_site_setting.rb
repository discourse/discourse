# frozen_string_literal: true

class AllowedUserLocalesSiteSetting < EnumSiteSetting
  def self.values
    LocaleSiteSetting.values
  end

  def self.translate_names?
    true
  end

  def self.valid_value?(value)
    return true if %w[all none].include?(value)

    locales = value.split("|", -1)
    locales.present? && locales.uniq == locales &&
      (locales - LocaleSiteSetting.supported_locales).empty?
  end
end
