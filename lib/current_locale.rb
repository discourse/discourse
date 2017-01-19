module CurrentLocale
  private

  def resolve_locale
    if !current_user
      locale_from_header || SiteSetting.default_locale
    else
      current_user.effective_locale
    end
  end

  def locale_from_header
    return unless SiteSetting.set_locale_from_accept_language_header

    begin
      # Rails I18n uses underscores between the locale and the region; the request
      # headers use hyphens.
      require 'http_accept_language' unless defined? HttpAcceptLanguage
      available_locales = I18n.available_locales.map { |locale| locale.to_s.tr('_', '-') }
      parser = HttpAcceptLanguage::Parser.new(request.env["HTTP_ACCEPT_LANGUAGE"])
      parser.language_region_compatible_from(available_locales).tr('-', '_')
    rescue
      # If Accept-Language headers are not set.
      nil
    end
  end

end
