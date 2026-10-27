# frozen_string_literal: true

class HashtagRemapper
  class PostStore < Store
    def self.key = "post"
    def self.raw_column = :raw
    def self.cooked(post) = post.cooked
    def self.cook_options(post) = post.markdown_options

    def self.relation
      Post
        .where.not(cook_method: Post.cook_methods[:raw_html])
        .joins(:topic)
        .where(topics: { deleted_at: nil })
    end

    def self.candidates(old_ref)
      super.or(relation.where("form_data::text ILIKE ?", HashtagRewriter.sql_like_pattern(old_ref)))
    end

    def self.rewrite_changes_content?(post, new_raw, &rewrite)
      super ||
        (post.form_data && post.form_submission.rewrite_text(&rewrite).to_h != post.form_data)
    end

    def self.write!(post, raw, &rewrite)
      post.with_lock do
        if rewrite
          post.assign_attributes(post.rewritten_content(&rewrite))
          raw = post.raw
        end
        super(post, raw)
      end
      post.sync_first_post_caches
      post.trigger_post_process(
        bypass_bump: true,
        priority: :ultra_low,
        skip_pull_hotlinked_images: true,
      )
    end
  end
end
