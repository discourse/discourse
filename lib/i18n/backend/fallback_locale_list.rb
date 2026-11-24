# frozen_string_literal: true

module I18n
  module Backend
    # Configure custom fallback order
    class FallbackLocaleList < Hash
      ENGLISH_FALLBACK = [:en].freeze
      private_constant :ENGLISH_FALLBACK

      def [](locale)
        locale = locale.to_sym
        return ENGLISH_FALLBACK if locale == :en

        locale_list = [locale]

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
