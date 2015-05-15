class RTL

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def enabled?
    site_locale_rtl? || current_user_rtl?
  end

  def current_user_rtl?
    SiteSetting.allow_user_locale && user.try(:locale).in?(rtl_locales)
  end

  def site_locale_rtl?
    !SiteSetting.allow_user_locale && SiteSetting.default_locale.in?(rtl_locales)
  end

  def rtl_locales
    %w(he ar fa_IR)
  end

  def css_class
    enabled? ? 'rtl' : ''
  end

end
