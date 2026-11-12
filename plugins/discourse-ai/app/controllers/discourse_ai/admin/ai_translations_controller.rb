# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        render json: base_result
      end

      def progress
        return render json: { cached_at: nil, targets: [] } unless DiscourseAi::Translation.enabled?

        render json: DiscourseAi::Translation::Progress.fetch
      end

      def progress_detail
        target_type = params[:target_type]
        unless DiscourseAi::Translation::Progress.supported_target?(target_type)
          return head :not_found
        end

        unless DiscourseAi::Translation.enabled?
          return render json: { target_type:, cached_at: nil, locales: [] }
        end

        render json: DiscourseAi::Translation::Progress.fetch_detail(target_type)
      end

      private

      def base_result
        {
          enabled: DiscourseAi::Translation.enabled?,
          backfill_enabled: DiscourseAi::Translation.backfill_enabled?(target: Post),
          translation_enabled: SiteSetting.ai_translation_enabled,
          hourly_rate: SiteSetting.ai_translation_backfill_hourly_rate,
          backfill_start_date: SiteSetting.ai_translation_backfill_start_date.presence,
        }
      end
    end
  end
end
