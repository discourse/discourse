# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TagLocalizer
      def self.localize(tag, target_locale = I18n.locale, short_text_llm_model: nil)
        return if tag.blank? || target_locale.blank?

        target_locale = target_locale.to_s.sub("-", "_")

        translated_name =
          ShortTextTranslator.new(
            text: tag.name,
            target_locale:,
            llm_model: short_text_llm_model,
          ).translate

        translated_description =
          if tag.description.present?
            ShortTextTranslator.new(
              text: tag.description,
              target_locale:,
              llm_model: short_text_llm_model,
            ).translate
          end

        localization = TagLocalization.find_or_initialize_by(tag_id: tag.id, locale: target_locale)

        localization.name = translated_name
        localization.description = translated_description
        localization.save!
        localization
      end
    end
  end
end
