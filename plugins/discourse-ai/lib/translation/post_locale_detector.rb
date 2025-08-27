# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostLocaleDetector
      def self.detect_locale(post)
        return if post.blank?

        text = PostDetectionText.get_text(post)
        detected_locale = LanguageDetector.new(text, post:).detect
        locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        post.update_column(:locale, locale)
        locale
      end
    end
  end
end
