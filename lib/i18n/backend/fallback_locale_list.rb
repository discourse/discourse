module I18n
  module Backend
    # Configure custom fallback order
    class FallbackLocaleList < Hash
      def [](locale)
        fallback_locale = LocaleSiteSetting.fallback_locale(locale)
        [locale, fallback_locale, SiteSetting.default_locale.to_sym, :en].uniq.compact
      end
    end
  end
end
