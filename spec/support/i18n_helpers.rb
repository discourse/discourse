# frozen_string_literal: true

module I18nHelpers
  def allow_missing_translations
    original_handler = I18n.exception_handler
    I18n.exception_handler = nil
    Rails.application.config.i18n.raise_on_missing_translations = false
    yield
  ensure
    I18n.exception_handler = original_handler
    Rails.application.config.i18n.raise_on_missing_translations = true
  end
end
