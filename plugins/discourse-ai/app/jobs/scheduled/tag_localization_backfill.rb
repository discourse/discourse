# frozen_string_literal: true

module Jobs
  class TagLocalizationBackfill < ::Jobs::Scheduled
    every 1.hour
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      short_text_llm =
        find_llm_model_for_persona(SiteSetting.ai_translation_short_text_translator_persona)

      if short_text_llm && !LlmCreditAllocation.credits_available?(short_text_llm)
        Rails.logger.info(
          "Tag localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate

      Jobs.enqueue(:localize_tags, limit:)
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
