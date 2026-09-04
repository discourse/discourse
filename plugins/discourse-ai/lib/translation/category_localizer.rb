# frozen_string_literal: true

module DiscourseAi
  module Translation
    class CategoryLocalizer
      class << self
        def localize(
          category,
          target_locale = I18n.locale,
          short_text_llm_model: nil,
          post_raw_llm_model: nil,
          fields: nil
        )
          return if category.blank? || target_locale.blank?

          target_locale = target_locale.to_s.sub("-", "_")
          localization =
            CategoryLocalization.find_or_initialize_by(
              category_id: category.id,
              locale: target_locale,
            )
          fields = %w[name description] if fields.blank? || localization.new_record?

          if fields.include?("name")
            localization.name =
              ShortTextTranslator.new(
                text: category.name,
                target_locale:,
                llm_model: short_text_llm_model,
              ).translate
          end

          if fields.include?("description")
            localization.description =
              if category.description_excerpt.present?
                PostRawTranslator.new(
                  text: category.description_excerpt,
                  target_locale:,
                  llm_model: post_raw_llm_model,
                ).translate
              else
                ""
              end
          end
          localization.save!
          localization
        end
      end
    end
  end
end
