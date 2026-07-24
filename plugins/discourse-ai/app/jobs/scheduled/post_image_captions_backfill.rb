# frozen_string_literal: true

module Jobs
  class PostImageCaptionsBackfill < ::Jobs::Scheduled
    every 15.minutes
    cluster_concurrency 1
    sidekiq_options retry: false

    def execute(_args)
      return if !DiscourseAi::PostImageCaptions.enabled?
      return if !DiscourseAi::PostImageCaptions.generation_enabled?
      return if !DiscourseAi::PostImageCaptions.credits_available?

      limit = DiscourseAi::PostImageCaptions.backfill_limit
      return if limit <= 0

      DiscourseAi::PostImageCaptions
        .backfill_targets(limit:)
        .each do |target|
          Jobs.enqueue(
            :generate_post_image_captions,
            post_id: target[:post_id],
            locale: target[:locale],
          )
        end
    end
  end
end
