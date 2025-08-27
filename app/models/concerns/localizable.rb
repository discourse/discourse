# frozen_string_literal: true

module Localizable
  extend ActiveSupport::Concern

  included { has_many :localizations, class_name: "#{model_name}Localization", dependent: :destroy }

  # Returns the localization for the given locale, or the best match if an exact match is not found.
  # The query used to find the localization is optimized for performance, and assumes
  # that localizations are indexed by locale, and have been preloaded where necessary.
  # @return [Localization, nil] the localization object for the given locale, or nil if no match is found.
  def get_localization(locale = I18n.locale)
    locale_str = locale.to_s.sub("-", "_")

    # prioritise exact match
    if match = localizations.find { |l| l.locale == locale_str }
      return match
    end

    localizations.find { |l| LocaleNormalizer.is_same?(l.locale, locale_str) }
  end
end
