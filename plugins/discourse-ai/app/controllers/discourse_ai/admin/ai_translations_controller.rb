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

        # TEMPORARY: Fake data for testing
        # Simulates: 100 English posts, 10 French posts, 5 Spanish posts
        # ALL locales show only posts requiring translation
        fake_progress = [
          { locale: "en", total: 15, done: 11 }, # 15 non-English posts, 11 translated to English
          { locale: "fr", total: 105, done: 50 }, # 105 non-French posts, 50 translated to French
          { locale: "es", total: 110, done: 30 }, # 110 non-Spanish posts, 30 translated to Spanish
        ]

        render json:
                 base_result.merge(
                   {
                     translation_progress: fake_progress,
                     total: 115,
                     posts_with_detected_locale: 115,
                   },
                 )
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
        }
      end
    end
  end
end
