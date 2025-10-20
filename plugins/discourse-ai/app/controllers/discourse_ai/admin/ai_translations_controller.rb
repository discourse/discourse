# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        supported_locales =
          SiteSetting.content_localization_supported_locales.presence&.split("|") || []

        if supported_locales.empty?
          return(
            render json:
                     base_result.merge(
                       {
                         translation_progress: [],
                         total: 0,
                         posts_with_detected_locale: 0,
                         no_locales_configured: true,
                       },
                     )
          )
        end

        totals = DiscourseAi::Translation::PostCandidates.get_total_and_with_locale_count
        progress = DiscourseAi::Translation::PostCandidates.get_completion_all_locales

        render json: base_result.merge(totals.merge(translation_progress: progress))
      end

      private

      def base_result
        {
          translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
          # the progress chart will be empty if max_age_days is 0
          enabled:
            DiscourseAi::Translation.enabled? &&
              SiteSetting.ai_translation_backfill_max_age_days > 0,
          backfill_enabled: DiscourseAi::Translation.backfill_enabled?,
          translation_enabled: SiteSetting.ai_translation_enabled,
          hourly_rate: SiteSetting.ai_translation_backfill_hourly_rate,
          backfill_max_age_days: SiteSetting.ai_translation_backfill_max_age_days,
        }
      end
    end
  end
end
