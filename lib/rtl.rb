# frozen_string_literal: true

class Rtl
  LOCALES = %w[ar fa_IR he ug ur]

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def enabled?
    site_locale_rtl? || current_user_rtl?
  end

  def current_user_rtl?
    SiteSetting.allowed_user_locales.present? &&
      (user&.locale || SiteSetting.default_locale).in?(LOCALES)
  end

  def site_locale_rtl?
    SiteSetting.allowed_user_locales.blank? && SiteSetting.default_locale.in?(LOCALES)
  end

  def css_class
    enabled? ? "rtl" : ""
  end
end
