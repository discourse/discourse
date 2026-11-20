# frozen_string_literal: true

class AllowedUserLocaleSiteSetting < EnumSiteSetting
  def self.translate_names?
    true
  end

  def self.valid_value?(value)
    value == "all" || LocaleSiteSetting.valid_value?(value)
  end

  def self.values
    [{ value: "all", name: "allowed_user_locales.all" }, *LocaleSiteSetting.values]
  end
end
