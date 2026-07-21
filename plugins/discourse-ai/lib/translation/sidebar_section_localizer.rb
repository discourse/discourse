# frozen_string_literal: true

module DiscourseAi
  module Translation
    class SidebarSectionLocalizer
      def self.localize(sidebar_section, target_locale = I18n.locale, short_text_llm_model: nil)
        return if sidebar_section.blank? || !sidebar_section.custom_section? || target_locale.blank?

        target_locale = target_locale.to_s.sub("-", "_")

        translated_title =
          ShortTextTranslator.new(
            text: sidebar_section.title,
            target_locale:,
            llm_model: short_text_llm_model,
          ).translate

        localization =
          SidebarSectionLocalization.find_or_initialize_by(
            sidebar_section_id: sidebar_section.id,
            locale: target_locale,
          )
        localization.title = translated_title
        localization.save!

        sidebar_section.sidebar_urls.each do |sidebar_url|
          translated_name =
            ShortTextTranslator.new(
              text: sidebar_url.name,
              target_locale:,
              llm_model: short_text_llm_model,
            ).translate

          url_localization =
            SidebarUrlLocalization.find_or_initialize_by(
              sidebar_url_id: sidebar_url.id,
              locale: target_locale,
            )
          url_localization.name = translated_name
          url_localization.save!
        end

        localization
      end
    end
  end
end
