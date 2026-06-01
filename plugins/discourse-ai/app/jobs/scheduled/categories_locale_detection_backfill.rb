# frozen_string_literal: true

module Jobs
  class CategoriesLocaleDetectionBackfill < ::Jobs::Scheduled
    every 1.hour
    sidekiq_options retry: false
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      llm_model = find_llm_model
      return if llm_model.blank?

      unless LlmCreditAllocation.credits_available?(llm_model)
        Rails.logger.info(
          "Categories locale detection backfill skipped: insufficient credits. Will resume when credits reset.",
        )
        return
      end

      categories = Category.where(locale: nil)
      excluded_category_ids = DiscourseAi::Translation.excluded_category_ids
      categories = categories.where.not(id: excluded_category_ids) if excluded_category_ids.present?

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

    private

    def find_llm_model
      agent_klass = AiAgent.find_by_id_from_cache(SiteSetting.ai_translation_locale_detector_agent)
      return nil if agent_klass.blank?

      DiscourseAi::Translation::BaseTranslator.preferred_llm_model(agent_klass)
    end
  end
end
