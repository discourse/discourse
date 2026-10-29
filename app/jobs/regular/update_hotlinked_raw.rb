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

      rewrite = ->(text) do
        InlineUploads.replace_hotlinked_image_urls(raw: text) do |match_src|
          normalized_match_src = PostHotlinkedMedia.normalize_src(match_src)
          hotlinked_map[normalized_match_src]&.upload
        end
      end
      raw = rewrite.call(post.raw)

      if post.raw != raw
        changes = { raw: raw, edit_reason: I18n.t("upload.edit_reason") }
        if (form_data = rewritten_form_data(post, rewrite))
          changes[:form_data] = form_data
        end
        post.revise(
          Discourse.system_user,
          changes,
          bypass_bump: true,
          skip_staff_log: true,
          skip_validations: true,
        )
      end
    end

    private

    # An oversized rewrite falls back to markdown editing rather than block the raw rewrite.
    def rewritten_form_data(post, rewrite)
      post.form_submission&.rewrite_answers(&rewrite)&.to_h
    rescue FormTemplate::Submission::TooLarge
      nil
    end
  end
end
