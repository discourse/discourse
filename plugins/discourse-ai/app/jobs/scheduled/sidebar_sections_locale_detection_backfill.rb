# frozen_string_literal: true

module Jobs
  class SidebarSectionsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.content_localization_enabled
      return if !DiscourseAi::Translation.backfill_enabled?(target: SidebarSection)

      return if !DiscourseAi::Translation.locale_detector_configured?

      unless DiscourseAi::Translation.credits_available_for_locale_detection?
        Rails.logger.info(
          "Sidebar section locale detection backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      sidebar_sections =
        DiscourseAi::Translation::SidebarSectionCandidates
          .get
          .includes(:sidebar_urls)
          .where(locale: nil)
          .limit(SiteSetting.ai_translation_backfill_hourly_rate)
      return if sidebar_sections.empty?

      sidebar_sections.each do |sidebar_section|
        DiscourseAi::Translation::SidebarSectionLocaleDetector.detect_locale(sidebar_section)
      rescue FinalDestination::SSRFDetector::LookupFailedError
      rescue => e
        DiscourseAi::Translation::VerboseLogger.log(
          "Failed to detect sidebar section #{sidebar_section.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
        )
      end

      DiscourseAi::Translation::VerboseLogger.log(
        "Detected #{sidebar_sections.size} sidebar section locales",
      )
    end
  end
end
