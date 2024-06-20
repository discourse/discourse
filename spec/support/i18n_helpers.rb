# frozen_string_literal: true

module I18nHelpers
  def allow_missing_translations
    Rails.application.config.i18n.raise_on_missing_translations = false
    yield
  ensure
    Rails.application.config.i18n.raise_on_missing_translations = true
  end
end
