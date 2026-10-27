# frozen_string_literal: true

module Jobs
  class UpdateHotlinkedRaw < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      @post_id = args[:post_id]
      raise Discourse::InvalidParameters.new(:post_id) if @post_id.blank?

      post = Post.find_by(id: @post_id)
      return if post.nil?
      return if post.cook_method == Post.cook_methods[:raw_html]
      return if post.topic.nil?

      hotlinked_map = post.post_hotlinked_media.preload(:upload).index_by { |r| r.url }

      post.with_lock do
        rewrite = ->(text) do
          InlineUploads.replace_hotlinked_image_urls(raw: text) do |match_src|
            normalized_match_src = PostHotlinkedMedia.normalize_src(match_src)
            hotlinked_map[normalized_match_src]&.upload
          end
        end
        content = post.rewritten_content(&rewrite)

        if content.any? { |field, value| post.public_send(field) != value }
          changes = content.merge(edit_reason: I18n.t("upload.edit_reason"))
          post.revise(
            Discourse.system_user,
            changes,
            bypass_bump: true,
            skip_staff_log: true,
            skip_validations: true,
          )
        end
      end
    end
  end
end
