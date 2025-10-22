# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostLocaleDetector
      def self.detect_locale(post)
        return if post.blank?

        text = PostDetectionText.get_text(post)

        if text.blank?
          locale = SiteSetting.default_locale
        else
          detected_locale = LanguageDetector.new(text, post:).detect
          locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        end

        post.update_column(:locale, locale)
        locale
      end
    end
  end
end
