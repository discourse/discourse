class RTL

  def self.enabled?
    site_locale_rtl? || current_user_rtl?
  end

  def self.current_user_rtl?
    SiteSetting.allow_user_locale && current_user.try(:locale).in?(rtl_locales)
  end

  def self.site_locale_rtl?
    !SiteSetting.allow_user_locale && SiteSetting.default_locale.in?(rtl_locales)
  end

  def self.rtl_locales
    %w(he ar)
  end

  def self.html_class
    enabled? ? 'rtl' : ''
  end

end
