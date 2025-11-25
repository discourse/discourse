# frozen_string_literal: true

module Localizable
  extend ActiveSupport::Concern

  included { has_many :localizations, class_name: "#{model_name}Localization", dependent: :destroy }

  # Returns the localization for (in order of priority):
  # - the given locale,
  # - or the best match if an exact match is not found
  # - or the site default locale if `content_localization_use_default_locale_when_unsupported` enabled
  #
  # The query used to find the localization is optimized for performance, and assumes
  # that localizations are indexed by locale, and have been preloaded.
  # @return [Localization, nil] the localization object for the given locale, or nil if no match is found.
  def get_localization(locale = I18n.locale)
    locale_str = locale.to_s.sub("-", "_")

    # prioritise exact match
    if match = localizations.find { |l| l.locale == locale_str }
      return match
    end

    if match = localizations.find { |l| LocaleNormalizer.is_same?(l.locale, locale_str) }
      return match
    end

    if SiteSetting.content_localization_use_default_locale_when_unsupported
      default_locale = SiteSetting.default_locale.to_s.sub("-", "_")
      localizations.find { |l| LocaleNormalizer.is_same?(l.locale, default_locale) }
    end
  end

  def in_user_locale?
    LocaleNormalizer.is_same?(locale, I18n.locale)
  end
end
