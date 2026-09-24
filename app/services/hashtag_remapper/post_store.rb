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

    def self.write!(post, raw)
      super
      post.sync_first_post_caches
      post.trigger_post_process(
        bypass_bump: true,
        priority: :ultra_low,
        skip_pull_hotlinked_images: true,
      )
    end
  end
end
