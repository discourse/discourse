# frozen_string_literal: true

module Localizable
  extend ActiveSupport::Concern

  included { has_many :localizations, class_name: "#{model_name}Localization", dependent: :destroy }

  def get_localization(locale = I18n.locale)
    locale_str = locale.to_s.sub("-", "_")

    # prioritise exact match
    if match = localizations.find { |l| l.locale == locale_str }
      return match
    end

    localizations.find { |l| LocaleNormalizer.is_same?(l.locale, locale_str) }
  end
end
