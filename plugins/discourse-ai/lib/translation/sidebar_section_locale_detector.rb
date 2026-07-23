# frozen_string_literal: true

module DiscourseAi
  module Translation
    class SidebarSectionLocaleDetector
      def self.detect_locale(sidebar_section)
        return if sidebar_section.blank?

        text =
          ([sidebar_section.title] + sidebar_section.sidebar_urls.map(&:name)).compact.join("\n\n")
        return if text.blank?

        detected_locale = LanguageDetector.new(text).detect
        return if detected_locale.blank?

        locale = LocaleNormalizer.normalize_to_i18n(detected_locale)
        sidebar_section.update_column(:locale, locale)
        sidebar_section.sidebar_urls.where(locale: nil).update_all(locale:)
        locale
      end
    end
  end
end
