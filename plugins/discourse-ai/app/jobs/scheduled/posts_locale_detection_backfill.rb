# frozen_string_literal: true

module Jobs
  class PostsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

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
  end
end
