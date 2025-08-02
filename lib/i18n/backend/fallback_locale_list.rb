# frozen_string_literal: true

module I18n
  module Backend
    # Configure custom fallback order
    class FallbackLocaleList < Hash
      def [](locale)
        locale = locale.to_sym
        locale_list = [locale]
        return locale_list if locale == :en

        while (fallback_locale = LocaleSiteSetting.fallback_locale(locale))
          locale_list << fallback_locale
          locale = fallback_locale
        end

        locale_list << :en
        locale_list.uniq.compact
      end
    end
  end
end
