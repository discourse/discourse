# frozen_string_literal: true

module DiscourseAi
  module Translation
    def self.enabled?
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled && has_llm_model? &&
        SiteSetting.content_localization_supported_locales.present?
    end

    def self.has_llm_model?
      persona_ids = [
        SiteSetting.ai_translation_locale_detector_persona,
        SiteSetting.ai_translation_post_raw_translator_persona,
        SiteSetting.ai_translation_topic_title_translator_persona,
        SiteSetting.ai_translation_short_text_translator_persona,
      ]

      persona_default_llms =
        AiPersona
          .all_personas(enabled_only: false)
          .select { |p| persona_ids.include?(p.id) }
          .map(&:default_llm_id)
      default_llm_model = SiteSetting.ai_default_llm_model

      if persona_default_llms.any?(&:blank?) && default_llm_model.blank?
        false
      else
        true
      end
    end

    def self.backfill_enabled?
      enabled? && SiteSetting.ai_translation_backfill_hourly_rate > 0 &&
        SiteSetting.ai_translation_backfill_max_age_days > 0
    end

    def self.llm_model_for_persona(persona_id)
      return nil if persona_id.blank?

      ai_persona = AiPersona.find_by(id: persona_id)
      return nil if ai_persona.blank?

      persona_klass = ai_persona.class_instance
      BaseTranslator.preferred_llm_model(persona_klass)
    end

    def self.credits_available_for_persona_ids?(persona_ids)
      return true if persona_ids.blank?

      models = persona_ids.map { |persona_id| llm_model_for_persona(persona_id) }.compact.uniq

      return true if models.empty?

      models.all? { |model| LlmCreditAllocation.credits_available?(model) }
    end

    def self.credits_available_for_post_detection?
      credits_available_for_persona_ids?(
        [
          SiteSetting.ai_translation_locale_detector_persona,
          SiteSetting.ai_translation_post_raw_translator_persona,
        ],
      )
    end

    def self.credits_available_for_topic_detection?
      credits_available_for_persona_ids?(
        [
          SiteSetting.ai_translation_locale_detector_persona,
          SiteSetting.ai_translation_topic_title_translator_persona,
          SiteSetting.ai_translation_post_raw_translator_persona,
        ],
      )
    end

    def self.credits_available_for_post_localization?
      credits_available_for_persona_ids?([SiteSetting.ai_translation_post_raw_translator_persona])
    end

    def self.credits_available_for_topic_localization?
      credits_available_for_persona_ids?(
        [
          SiteSetting.ai_translation_topic_title_translator_persona,
          SiteSetting.ai_translation_post_raw_translator_persona,
        ],
      )
    end

    def self.credits_available_for_category_localization?
      credits_available_for_persona_ids?(
        [
          SiteSetting.ai_translation_short_text_translator_persona,
          SiteSetting.ai_translation_post_raw_translator_persona,
        ],
      )
    end
  end
end
