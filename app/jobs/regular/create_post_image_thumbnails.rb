# frozen_string_literal: true

module Jobs
  # Generates the thumbnails a post-processing pass deferred, then re-runs
  # post-processing so the cooked HTML switches from originals to thumbnails.
  class CreatePostImageThumbnails < ::Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])
      return if post.blank? || post.topic.blank?

      thumbnails = Array(args[:thumbnails])
      uploads =
        Upload.where(id: thumbnails.map { |thumbnail| thumbnail[:upload_id] }).index_by(&:id)

      thumbnails.each do |thumbnail|
        upload = uploads[thumbnail[:upload_id]]
        next if upload.blank?

        upload.create_thumbnail!(thumbnail[:width], thumbnail[:height], crop: !!thumbnail[:crop])
        upload.dominant_color(calculate_if_missing: true)
      end

      Jobs.enqueue(
        :process_post,
        post_id: post.id,
        cooking_options: args[:cooking_options],
        image_sizes: args[:image_sizes],
        defer_thumbnails: false,
        bypass_bump: true,
        skip_pull_hotlinked_images: true,
      )
    end
  end
end
