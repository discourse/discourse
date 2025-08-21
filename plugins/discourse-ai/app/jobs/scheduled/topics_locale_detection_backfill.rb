# frozen_string_literal: true

module Jobs
  class TopicsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

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
  end
end
