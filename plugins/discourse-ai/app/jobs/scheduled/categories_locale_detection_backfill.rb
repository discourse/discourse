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

      if SiteSetting.ai_translation_backfill_limit_to_public_content
        categories = categories.where(read_restricted: false)
      end

      limit = SiteSetting.ai_translation_backfill_hourly_rate
      categories = categories.limit(limit)
      return if categories.empty?

      categories.each do |category|
        begin
          DiscourseAi::Translation::CategoryLocaleDetector.detect_locale(category)
        rescue FinalDestination::SSRFDetector::LookupFailedError
        rescue => e
          DiscourseAi::Translation::VerboseLogger.log(
            "Failed to detect category #{category.id}'s locale: #{e.message}\n\n#{e.backtrace[0..3].join("\n")}",
          )
        end
      end

      DiscourseAi::Translation::VerboseLogger.log("Detected #{categories.size} category locales")
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
