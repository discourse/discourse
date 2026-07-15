# frozen_string_literal: true

module Jobs
  class PostImageDescriptionsBackfill < ::Jobs::Scheduled
    every 15.minutes
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(_args)
      return if !DiscourseAi::PostImageDescriptions.enabled?
      return if !DiscourseAi::PostImageDescriptions.generation_enabled?
      return if !DiscourseAi::PostImageDescriptions.credits_available?

      limit = DiscourseAi::PostImageDescriptions.backfill_limit
      return if limit <= 0

      DiscourseAi::PostImageDescriptions
        .backfill_targets(limit:)
        .each do |target|
          Jobs.enqueue(
            :generate_post_image_descriptions,
            post_id: target[:post_id],
            locale: target[:locale],
          )
        end
    end
  end
end
