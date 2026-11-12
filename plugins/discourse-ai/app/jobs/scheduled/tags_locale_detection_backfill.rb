# frozen_string_literal: true

module Jobs
  class TagsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?(target: Tag)

      return if !DiscourseAi::Translation.locale_detector_configured?

      unless DiscourseAi::Translation.credits_available_for_locale_detection?
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
        DiscourseAi::Translation::TagLocaleDetector.detect_locale(tag)
      rescue FinalDestination::SSRFDetector::LookupFailedError
      rescue => e
        DiscourseAi::Translation::VerboseLogger.log(
          "Failed to detect tag #{tag.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
        )
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{tags.size} tag locales")
    end
  end
end
