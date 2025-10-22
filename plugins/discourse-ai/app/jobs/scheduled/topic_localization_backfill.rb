# frozen_string_literal: true

module Jobs
  class TopicLocalizationBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      topic_title_llm =
        find_llm_model_for_persona(SiteSetting.ai_translation_topic_title_translator_persona)
      post_raw_llm =
        find_llm_model_for_persona(SiteSetting.ai_translation_post_raw_translator_persona)

      if (topic_title_llm && !LlmCreditAllocation.credits_available?(topic_title_llm)) ||
           (post_raw_llm && !LlmCreditAllocation.credits_available?(post_raw_llm))
        Rails.logger.info(
          "Topic localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals
      Jobs.enqueue(:localize_topics, limit:)
    end

    private

    def find_llm_model_for_persona(persona_id)
      return nil if persona_id.blank?

      ai_persona = AiPersona.find_by_id_from_cache(persona_id)
      return nil if ai_persona.blank?

      persona_klass = ai_persona.class_instance
      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
