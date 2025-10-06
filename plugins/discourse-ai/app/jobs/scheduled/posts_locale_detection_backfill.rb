# frozen_string_literal: true

module Jobs
  class PostsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      llm_model = find_llm_model
      return if llm_model.blank?

      begin
        LlmCreditAllocation.check_credits!(llm_model)
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        Rails.logger.info(
          "Posts locale detection backfill skipped: #{e.message}. Will resume when credits reset.",
        )
        return
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals

      posts =
        DiscourseAi::Translation::PostCandidates
          .get()
          .where(locale: nil)
          .order(updated_at: :desc)
          .limit(limit)

      return if posts.empty?

      posts.each do |post|
        begin
          DiscourseAi::Translation::PostLocaleDetector.detect_locale(post)
        rescue FinalDestination::SSRFDetector::LookupFailedError
          # do nothing, there are too many sporadic lookup failures
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect post #{post.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{posts.size} post locales")
    end

    private

    def find_llm_model
      ai_persona = AiPersona.find_by(id: SiteSetting.ai_translation_locale_detector_persona)
      return nil if ai_persona.blank?

      persona_klass = ai_persona.class_instance
      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(persona_klass)
    end
  end
end
