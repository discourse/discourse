# frozen_string_literal: true

module Jobs
  class CategoryLocalizationBackfill < ::Jobs::Scheduled
    every 1.hour
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      short_text_llm =
        find_llm_model_for_agent(SiteSetting.ai_translation_short_text_translator_agent)
      post_raw_llm = find_llm_model_for_agent(SiteSetting.ai_translation_post_raw_translator_agent)

      if (short_text_llm && !LlmCreditAllocation.credits_available?(short_text_llm)) ||
           (post_raw_llm && !LlmCreditAllocation.credits_available?(post_raw_llm))
        Rails.logger.info(
          "Category localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate

      Jobs.enqueue(:localize_categories, limit:)
    end

    private

    def find_llm_model_for_agent(agent_id)
      return nil if agent_id.blank?

      agent_klass = AiAgent.find_by_id_from_cache(agent_id)
      return nil if agent_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
    end
  end
end
