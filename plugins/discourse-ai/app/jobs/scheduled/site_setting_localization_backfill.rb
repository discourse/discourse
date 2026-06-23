# frozen_string_literal: true

module Jobs
  class SiteSettingLocalizationBackfill < ::Jobs::Scheduled
    every 1.hour
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      short_text_llm =
        DiscourseAi::Translation.llm_model_for_agent(
          SiteSetting.ai_translation_short_text_translator_agent,
        )
      post_raw_llm =
        DiscourseAi::Translation.llm_model_for_agent(
          SiteSetting.ai_translation_post_raw_translator_agent,
        )

      if (short_text_llm && !LlmCreditAllocation.credits_available?(short_text_llm)) ||
           (post_raw_llm && !LlmCreditAllocation.credits_available?(post_raw_llm))
        Rails.logger.info(
          "Site setting localization backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      Jobs.enqueue(:localize_site_settings, limit: SiteSetting.ai_translation_backfill_hourly_rate)
    end
  end
end
