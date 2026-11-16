# frozen_string_literal: true

module Jobs
  class CategoriesLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?(target: Category)

      return if !DiscourseAi::Translation.locale_detector_configured?

      unless DiscourseAi::Translation.credits_available_for_locale_detection?
        Rails.logger.info(
          "Categories locale detection backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      categories = DiscourseAi::Translation::CategoryCandidates.get.where(locale: nil)

      limit = SiteSetting.ai_translation_backfill_hourly_rate
      categories = categories.limit(limit)
      return if categories.empty?

      categories.each do |category|
        DiscourseAi::Translation::CategoryLocaleDetector.detect_locale(category)
      rescue FinalDestination::SSRFDetector::LookupFailedError
      rescue => e
        DiscourseAi::Translation::VerboseLogger.log(
          "Failed to detect category #{category.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
        )
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{categories.size} category locales")
    end
  end
end
