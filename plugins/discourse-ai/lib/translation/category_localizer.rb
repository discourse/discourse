# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryLocalizer
      def self.localize(
        category,
        target_locale = I18n.locale,
        short_text_llm_model: nil,
        post_raw_llm_model: nil
      )
        return if category.blank? || target_locale.blank?

        target_locale = target_locale.to_s.sub("-", "_")

        translated_name =
          ShortTextTranslator.new(
            text: category.name,
            target_locale:,
            llm_model: short_text_llm_model,
          ).translate
        translated_description =
          if category.description_excerpt.present?
            PostRawTranslator.new(
              text: category.description_excerpt,
              target_locale:,
              llm_model: post_raw_llm_model,
            ).translate
          else
            ""
          end

        localization =
          CategoryLocalization.find_or_initialize_by(
            category_id: category.id,
            locale: target_locale,
          )

        localization.name = translated_name
        localization.description = translated_description
        localization.save!
        localization
      end
    end
  end
end
