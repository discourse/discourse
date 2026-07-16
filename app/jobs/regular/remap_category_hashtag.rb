# frozen_string_literal: true

module Jobs
  class RemapCategoryHashtag < ::Jobs::Base
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      return if args[:category_id].blank?
      category = category_from(args)
      return if category.blank?

      old_ref = args[:old_ref].presence
      new_ref = category&.slug_ref.presence || args[:new_ref].presence
      return if old_ref.blank? || new_ref.blank? || old_ref == new_ref

      posts_matching(old_ref, category.id).find_each { |post| update_post(post, old_ref, new_ref) }
    end

    private

    def category_from(args)
      Category.find_by(id: args[:category_id])
    end

    def posts_matching(old_ref, category_id)
      posts =
        Post
          .joins(:topic)
          .where("topics.deleted_at IS NULL")
          .where("posts.raw ~* ?", "(?n)#{raw_hashtag_pattern(old_ref)}")

      # More accurate way to find matching hashtags than looking
      # at raw since we can have tags/chat channels with the same
      # hashtag ref
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
    rescue => err
      Discourse.warn_exception(
        err,
        message:
          "Failed to remap category hashtag #{old_ref} to #{new_ref} for category ID #{category.id} in post ID #{post.id}",
      )
    end

    def raw_hashtag_pattern(ref)
      "(?<![:\\w])##{Regexp.escape(ref)}(?![\\w:-])"
    end

    def raw_hashtag_regex(ref)
      /(?<![:\w])##{Regexp.escape(ref)}(?![\w:-])/i
    end
  end
end
