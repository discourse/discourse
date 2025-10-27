# frozen_string_literal: true

module Jobs
  class PostLocalizationBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      post_raw_llm =
        find_llm_model_for_persona(SiteSetting.ai_translation_post_raw_translator_persona)

      if post_raw_llm && !LlmCreditAllocation.credits_available?(post_raw_llm)
        Rails.logger.info(
          "Post localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals
      return if limit == 0

      Jobs.enqueue(:localize_posts, limit:)
    end

    private

    def find_llm_model_for_persona(persona_id)
      return nil if persona_id.blank?

      persona_klass = AiPersona.find_by_id_from_cache(persona_id)
      return nil if persona_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
