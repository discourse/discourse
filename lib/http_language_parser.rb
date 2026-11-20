# frozen_string_literal: true

module HttpLanguageParser
  def self.parse(header, locales: I18n.available_locales)
    match(header, locales:) || SiteSetting.default_locale
  end

  def self.match(header, locales:)
    # Rails I18n uses underscores between the locale and the region; the request
    # headers use hyphens.
    require "http_accept_language" unless defined?(HttpAcceptLanguage)
    available_locales = locales.map { |locale| locale.to_s.tr("_", "-") }
    parser = HttpAcceptLanguage::Parser.new(header&.tr("_", "-"))
    parser.language_region_compatible_from(available_locales)&.tr("-", "_")
  end
end
