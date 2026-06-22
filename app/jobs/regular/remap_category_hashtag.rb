# frozen_string_literal: true

module Jobs
  class RemapCategoryHashtag < ::Jobs::Base
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      old_ref = args[:old_ref].presence
      new_ref = current_ref(args).presence || args[:new_ref].presence
      return if old_ref.blank? || new_ref.blank? || old_ref == new_ref

      posts_matching(old_ref, args[:category_id]).find_each do |post|
        update_post(post, old_ref, new_ref)
      end
    end

    private

    def current_ref(args)
      Category.find_by(id: args[:category_id])&.slug_ref if args[:category_id].present?
    end

    def posts_matching(old_ref, category_id)
      category_id = category_id.to_i if category_id.present?
      posts =
        Post
          .joins(:topic)
          .where("topics.deleted_at IS NULL")
          .where("posts.raw ~* ?", "(?n)#{raw_hashtag_pattern(old_ref)}")

      if category_id.present?
        posts =
          posts.where(
            "posts.cooked LIKE ? AND posts.cooked LIKE ?",
            '%data-type="category"%',
            "%data-id=\"#{category_id}\"%",
          )
      end

      posts
    end

    def update_post(post, old_ref, new_ref)
      new_raw = post.raw.gsub(raw_hashtag_regex(old_ref), "##{new_ref}")
      return if new_raw == post.raw

      post.revise(Discourse.system_user, { raw: new_raw }, bypass_bump: true, skip_revision: true)
    rescue => e
      Discourse.warn_exception(e, message: "Failed to remap category hashtag in post #{post.id}")
    end

    def raw_hashtag_pattern(ref)
      "(?<![:\\w])##{Regexp.escape(ref)}(?![\\w:-])"
    end

    def raw_hashtag_regex(ref)
      /(?<![:\w])##{Regexp.escape(ref)}(?![\w:-])/i
    end
  end
end
