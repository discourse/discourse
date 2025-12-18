# frozen_string_literal: true

module Jobs
  class TagsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      llm_model = find_llm_model
      return if llm_model.blank?

      unless LlmCreditAllocation.credits_available?(llm_model)
        Rails.logger.info(
          "Tags locale detection backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      tags =
        DiscourseAi::Translation::TagCandidates
          .get
          .where(locale: nil)
          .limit(SiteSetting.ai_translation_backfill_hourly_rate)
      return if tags.empty?

      tags.each do |tag|
        begin
          DiscourseAi::Translation::TagLocaleDetector.detect_locale(tag)
        rescue FinalDestination::SSRFDetector::LookupFailedError
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect tag #{tag.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{tags.size} tag locales")
    end

    private

    def find_llm_model
      persona_klass =
        AiPersona.find_by_id_from_cache(SiteSetting.ai_translation_locale_detector_persona)
      return nil if persona_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
