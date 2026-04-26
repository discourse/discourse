# frozen_string_literal: true

module DiscourseAi
  module Translation
    def self.enabled?
      SiteSetting.discourse_ai_enabled && SiteSetting.ai_translation_enabled && has_llm_model? &&
        SiteSetting.content_localization_supported_locales.present?
    end

    def self.locales
      SiteSetting.content_localization_locales
    end

    def self.has_llm_model?
      agent_ids = [
        SiteSetting.ai_translation_locale_detector_agent,
        SiteSetting.ai_translation_post_raw_translator_agent,
        SiteSetting.ai_translation_topic_title_translator_agent,
        SiteSetting.ai_translation_short_text_translator_agent,
      ]

      agent_default_llms =
        AiAgent
          .all_agents(enabled_only: false)
          .select { |p| agent_ids.include?(p.id) }
          .map(&:default_llm_id)
      default_llm_model = SiteSetting.ai_default_llm_model

      if agent_default_llms.any?(&:blank?) && default_llm_model.blank?
        false
      else
        true
      end
    end

    def self.backfill_enabled?
      enabled? && SiteSetting.ai_translation_backfill_hourly_rate > 0 &&
        SiteSetting.ai_translation_backfill_max_age_days > 0
    end

    def self.llm_model_for_agent(agent_id)
      return nil if agent_id.blank?

      ai_agent = AiAgent.find_by_id_from_cache(agent_id)
      return nil if ai_agent.blank?

      agent_klass = ai_agent.class_instance
      BaseTranslator.preferred_llm_model(agent_klass)
    end

    def self.credits_available_for_agent_ids?(agent_ids)
      return true if agent_ids.blank?

      models = agent_ids.map { |agent_id| llm_model_for_agent(agent_id) }.compact.uniq

      return true if models.empty?

      models.all? { |model| LlmCreditAllocation.credits_available?(model) }
    end

    def self.credits_available_for_post_detection?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_locale_detector_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_topic_detection?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_locale_detector_agent,
          SiteSetting.ai_translation_topic_title_translator_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_post_localization?
      credits_available_for_agent_ids?([SiteSetting.ai_translation_post_raw_translator_agent])
    end

    def self.credits_available_for_topic_localization?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_topic_title_translator_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_category_localization?
      credits_available_for_agent_ids?(
        [
          SiteSetting.ai_translation_short_text_translator_agent,
          SiteSetting.ai_translation_post_raw_translator_agent,
        ],
      )
    end

    def self.credits_available_for_tag_localization?
      credits_available_for_agent_ids?([SiteSetting.ai_translation_short_text_translator_agent])
    end
  end
end
