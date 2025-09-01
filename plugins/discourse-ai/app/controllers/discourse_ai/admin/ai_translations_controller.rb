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
            render json: {
                     translation_progress: [],
                     translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
                     enabled: DiscourseAi::Translation.backfill_enabled?,
                     total: 0,
                     posts_with_detected_locale: 0,
                   }
          )
        end

        candidates = DiscourseAi::Translation::PostCandidates

        result =
          supported_locales.map do |locale|
            candidates.get_completion_per_locale(locale) in { total:, done: }
            { locale:, total:, done: }
          end

        candidates.get_total_and_with_locale_count in { total:, posts_with_detected_locale: }

        render json: {
                 translation_progress: result,
                 translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
                 enabled: DiscourseAi::Translation.backfill_enabled?,
                 total:,
                 posts_with_detected_locale:,
               }
      end

      private

      def safe_percentage(part, total)
        return 0.0 if total <= 0
        (part / total) * 100
      end
    end
  end
end
