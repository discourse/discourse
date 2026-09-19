# frozen_string_literal: true

module Jobs
  class GeneratePostImageCaptions < ::Jobs::Base
    sidekiq_options queue: "low", retry: false

    def execute(args)
      post_id = args[:post_id]
      return if post_id.blank?

      post = Post.find_by(id: post_id)
      return if post.blank?

      locale = args[:locale].presence || DiscourseAi::PostImageCaptions.original_locale(post)

      DistributedMutex.synchronize(
        "generate_post_image_captions_#{post.id}_#{locale}",
        validity: 10.minutes,
      ) do
        DiscourseAi::PostImageCaptions.generate_missing(
          post,
          locale: locale,
          base62_sha1s: args[:base62_sha1s],
        )
      end
    end
  end
end
