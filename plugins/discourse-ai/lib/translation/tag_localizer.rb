# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TagLocalizer
      class << self
        def localize(tag, target_locale = I18n.locale, short_text_llm_model: nil, fields: nil)
          return if tag.blank? || target_locale.blank?

          target_locale = target_locale.to_s.sub("-", "_")
          localization =
            TagLocalization.find_or_initialize_by(tag_id: tag.id, locale: target_locale)
          fields = %w[name description] if fields.blank? || localization.new_record?

          if fields.include?("name")
            localization.name =
              ShortTextTranslator.new(
                text: tag.name,
                target_locale:,
                llm_model: short_text_llm_model,
              ).translate
          end

          if fields.include?("description")
            localization.description =
              if tag.description.present?
                ShortTextTranslator.new(
                  text: tag.description,
                  target_locale:,
                  llm_model: short_text_llm_model,
                ).translate
              end
          end
          localization.save!
          localization
        end
      end
    end
  end
end
