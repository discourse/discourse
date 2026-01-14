# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicLocaleDetector
      def self.detect_locale(topic)
        return if topic.blank?

        detected_locale = LanguageDetector.new(topic.title.dup, topic:).detect
        return if detected_locale.blank?

        locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        topic.update_column(:locale, locale)
        locale
      end
    end
  end
end
