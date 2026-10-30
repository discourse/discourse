# frozen_string_literal: true

module ::Blog
  module GuardianExtensions
    def can_edit_post?(post)
      if post.is_first_post? && blog_public_topic?(post.topic)
        return(
          Thread.current[:blog_publishing_topic] == post.topic_id &&
            Configuration.publisher?(user) && can_see?(post.topic)
        )
      end
      if post.is_first_post? && blog_editorial_topic?(post.topic) && !post.hidden? &&
           !post.deleted_at && (!post.locked? || is_staff?)
        return true
      end
      super
    end

    def can_edit_topic?(topic)
      if blog_public_topic?(topic)
        return(
          Thread.current[:blog_publishing_topic] == topic.id && Configuration.publisher?(user) &&
            can_see?(topic)
        )
      end
      return true if blog_editorial_topic?(topic) && (!topic.first_post&.locked? || is_staff?)
      super
    end

    private

    def blog_public_topic?(topic)
      SiteSetting.blog_enabled && topic&.category_id == SiteSetting.blog_category.to_i &&
        Publication
          .where(discussion_topic_id: topic.id)
          .where.not(published_revision_id: nil)
          .exists?
    end

    def blog_editorial_topic?(topic)
      SiteSetting.blog_enabled && topic &&
        topic.category_id == SiteSetting.blog_drafts_category.to_i && !topic.deleted_at &&
        !topic.archived? && !topic.private_message? && topic.category&.topic_id != topic.id &&
        Configuration.contributor?(user) &&
        (Configuration.editor?(user) || topic.user_id == user.id) && can_see?(topic)
    end
  end
end
