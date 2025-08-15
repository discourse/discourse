# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        supported_locales =
          SiteSetting.content_localization_supported_locales.presence&.split("|") || []

        result =
          supported_locales.map do |locale|
            completion_data =
              DiscourseAi::Translation::PostCandidates.get_completion_per_locale(locale)

            total = completion_data[:total].to_f
            done = completion_data[:done].to_f
            remaining = total - done

            completion_percentage = safe_percentage(done, total)
            remaining_percentage = safe_percentage(remaining, total)

            {
              locale: locale,
              completion_percentage: completion_percentage,
              remaining_percentage: remaining_percentage,
            }
          end

        render json: {
                 translation_progress: result,
                 translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
                 enabled: DiscourseAi::Translation.backfill_enabled?,
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
