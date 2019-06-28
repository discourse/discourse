# frozen_string_literal: true

module I18n
  module Backend
    # Configure custom fallback order
    class FallbackLocaleList < Hash
      def [](locale)
        locale = locale.to_sym
        return [locale] if locale == :en

        fallback_locale = LocaleSiteSetting.fallback_locale(locale)
        site_locale = SiteSetting.default_locale.to_sym

        locale_list =
          if locale == site_locale || site_locale == :en || fallback_locale == :en
            [locale, fallback_locale, :en]
          else
            site_fallback_locale = LocaleSiteSetting.fallback_locale(site_locale)
            [locale, fallback_locale, site_locale, site_fallback_locale, :en]
          end

        locale_list.uniq.compact
      end
    end
  end
end
