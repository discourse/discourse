# frozen_string_literal: true

module Jobs
  class SidebarSectionsLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !SiteSetting.content_localization_enabled
      return if !DiscourseAi::Translation.backfill_enabled?

      llm_model = find_llm_model
      return if llm_model.blank?

      unless LlmCreditAllocation.credits_available?(llm_model)
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

    private

    def find_llm_model
      agent_klass = AiAgent.find_by_id_from_cache(SiteSetting.ai_translation_locale_detector_agent)
      return nil if agent_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
    end
  end
end
