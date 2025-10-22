# frozen_string_literal: true

module Jobs
  class TopicsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      llm_model = find_llm_model
      return if llm_model.blank?

      unless LlmCreditAllocation.credits_available?(llm_model)
        Rails.logger.info(
          "Topics locale detection backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals

      topics =
        DiscourseAi::Translation::TopicCandidates
          .get()
          .where(locale: nil)
          .order(updated_at: :desc)
          .limit(limit)

      return if topics.empty?

      topics.each do |topic|
        begin
          DiscourseAi::Translation::TopicLocaleDetector.detect_locale(topic)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect topic #{topic.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{topics.size} topic locales")
    end

    private

    def find_llm_model
      ai_persona =
        AiPersona.find_by_id_from_cache(SiteSetting.ai_translation_locale_detector_persona)
      return nil if ai_persona.blank?

      persona_klass = ai_persona.class_instance
      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
