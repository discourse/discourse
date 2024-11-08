# frozen_string_literal: true

class Rtl
  LOCALES = %w[ar fa_IR he ug ur].freeze

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def enabled?
    site_locale_rtl? || current_user_rtl?
  end

  def current_user_rtl?
    SiteSetting.allow_user_locale && (user&.locale || SiteSetting.default_locale).in?(LOCALES)
  end

  def site_locale_rtl?
    !SiteSetting.allow_user_locale && SiteSetting.default_locale.in?(LOCALES)
  end

  def css_class
    enabled? ? "rtl" : ""
  end
end
