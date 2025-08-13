# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        supported_locales =
          SiteSetting.content_localization_supported_locales.presence&.split("|") || []
        result = []

        supported_locales.each do |locale|
          completion_percentage =
            DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)
          done, total =
            DiscourseAi::Translation::PostCandidates.send(:calculate_completion_per_locale, locale)
          todo_count = total - done

          result << {
            locale: locale,
            completion_percentage: completion_percentage,
            todo_count: todo_count,
          }
        end

        render json: {
                 translation_progress: result,
                 translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
                 enabled: DiscourseAi::Translation.backfill_enabled?,
               }
      end

      private
    end
  end
end
