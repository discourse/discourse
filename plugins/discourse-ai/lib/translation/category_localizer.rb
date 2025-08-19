# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryLocalizer
      def self.localize(category, target_locale = I18n.locale)
        return if category.blank? || target_locale.blank?

        target_locale = target_locale.to_s.sub("-", "_")

        translated_name = ShortTextTranslator.new(text: category.name, target_locale:).translate
        translated_description =
          if category.description_excerpt.present?
            PostRawTranslator.new(text: category.description_excerpt, target_locale:).translate
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
