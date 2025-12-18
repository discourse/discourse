# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TagLocaleDetector
      def self.detect_locale(tag)
        return if tag.blank?

        text = [tag.name, tag.description].compact.join("\n\n")
        return if text.blank?

        detected_locale = LanguageDetector.new(text).detect
        return if detected_locale.blank?

        locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        tag.update_column(:locale, locale)
        locale
      end
    end
  end
end
