# frozen_string_literal: true

module Jobs
  class PostLocalizationBackfill < ::Jobs::Scheduled
    every 5.minutes
    cluster_concurrency 1

    def execute(args)
      return if !DiscourseAi::Translation.backfill_enabled?

      limit = SiteSetting.ai_translation_backfill_hourly_rate / (60 / 5) # this job runs in 5-minute intervals
      return if limit == 0

      Jobs.enqueue(:localize_posts, limit:)
    end
  end
end
