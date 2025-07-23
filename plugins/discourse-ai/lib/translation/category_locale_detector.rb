# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryLocaleDetector
      def self.detect_locale(category)
        return if category.blank?

        text = [category.name, category.description].compact.join("\n\n")
        return if text.blank?

        detected_locale = LanguageDetector.new(text).detect
        locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        category.update_column(:locale, locale)
        locale
      end
    end
  end
end
