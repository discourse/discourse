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
                       { translation_progress: [], total: 0, posts_with_detected_locale: 0 },
                     )
          )
        end

        candidates = DiscourseAi::Translation::PostCandidates

        result =
          supported_locales.map do |locale|
            candidates.get_completion_per_locale(locale) in { total:, done: }
            { locale:, total:, done: }
          end

        candidates.get_total_and_with_locale_count in { total:, posts_with_detected_locale: }

        render json:
                 base_result.merge(
                   { translation_progress: result, total:, posts_with_detected_locale: },
                 )
      end

      private

      def base_result
        {
          translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
          enabled: DiscourseAi::Translation.enabled?,
          backfill_enabled: DiscourseAi::Translation.backfill_enabled?,
        }
      end
    end
  end
end
