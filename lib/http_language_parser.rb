# frozen_string_literal: true

module HttpLanguageParser
  def self.parse(header)
    # Rails I18n uses underscores between the locale and the region; the request
    # headers use hyphens.
    require "http_accept_language" unless defined?(HttpAcceptLanguage)
    available_locales = I18n.available_locales.map { |locale| locale.to_s.tr("_", "-") }
    parser = HttpAcceptLanguage::Parser.new(header)
    matched = parser.language_region_compatible_from(available_locales)&.tr("-", "_")
    matched || SiteSetting.default_locale
  end
end
