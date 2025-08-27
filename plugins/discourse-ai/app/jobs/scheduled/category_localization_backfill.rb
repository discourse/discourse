# frozen_string_literal: true

module Jobs
  class CategoryLocalizationBackfill < ::Jobs::Scheduled
    every 1.hour
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?
      limit = SiteSetting.ai_translation_backfill_hourly_rate

      Jobs.enqueue(:localize_categories, limit:)
    end
  end
end
