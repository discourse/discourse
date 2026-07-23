# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        supported_locales =
          SiteSetting.content_localization_supported_locales.presence&.split("|") || []

        result = base_result
        result[:no_locales_configured] = true if supported_locales.empty?

        render json: result
      end

      def progress
        return render json: { cached_at: nil, targets: [] } unless DiscourseAi::Translation.enabled?

        render json: DiscourseAi::Translation::Progress.fetch
      end

      private

      def base_result
        {
          translation_id: DiscourseAi::Configuration::Module::TRANSLATION_ID,
          enabled: DiscourseAi::Translation.enabled?,
          backfill_enabled: DiscourseAi::Translation.backfill_enabled?,
          translation_enabled: SiteSetting.ai_translation_enabled,
          hourly_rate: SiteSetting.ai_translation_backfill_hourly_rate,
          backfill_max_age_days: SiteSetting.ai_translation_backfill_max_age_days,
          category_scope: SiteSetting.ai_translation_category_scope,
          category_ids: DiscourseAi::Translation.category_ids,
        }
      end
    end
  end
end
