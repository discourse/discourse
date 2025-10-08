# frozen_string_literal: true

module Jobs
  class CategoryLocalizationBackfill < ::Jobs::Scheduled
    every 1.hour
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      short_text_llm =
        find_llm_model_for_persona(SiteSetting.ai_translation_short_text_translator_persona)
      post_raw_llm =
        find_llm_model_for_persona(SiteSetting.ai_translation_post_raw_translator_persona)

      begin
        LlmCreditAllocation.check_credits!(short_text_llm) if short_text_llm
        LlmCreditAllocation.check_credits!(post_raw_llm) if post_raw_llm
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        Rails.logger.info(
          "Category localization backfill skipped: #{e.message}. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate

      Jobs.enqueue(:localize_categories, limit:)
    end

    private

    def find_llm_model_for_persona(persona_id)
      return nil if persona_id.blank?

      ai_persona = AiPersona.find_by(id: persona_id)
      return nil if ai_persona.blank?

      persona_klass = ai_persona.class_instance
      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
