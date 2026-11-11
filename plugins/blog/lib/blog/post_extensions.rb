# frozen_string_literal: true

module ::Blog
  module PostExtensions
    def self.prepended(base)
      base.after_update :blog_revoke_reviews
    end

    private

    def blog_revoke_reviews
      return unless SiteSetting.blog_enabled
      if post_number == 1 &&
           ((saved_change_to_hidden? && hidden?) || (saved_change_to_deleted_at? && deleted_at))
        Blog::Review.revoke_for_topic!(topic_id)
      end
    end
  end
end
