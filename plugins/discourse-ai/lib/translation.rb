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

      persona_default_llms = AiPersona.where(id: persona_ids).pluck(:default_llm_id)
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
  end
end
