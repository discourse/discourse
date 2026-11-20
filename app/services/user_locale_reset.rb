# frozen_string_literal: true

class UserLocaleReset
  def initialize(value, default_locale: SiteSetting.default_locale)
    @removed_locales =
      SiteSetting.allowed_user_locale_values -
        SiteSetting.allowed_user_locale_values(value, default_locale:)
  end

  def required?
    @removed_locales.present?
  end

  def apply
    User.real.where(locale: @removed_locales).update_all(locale: nil, updated_at: Time.current)
  end
end
