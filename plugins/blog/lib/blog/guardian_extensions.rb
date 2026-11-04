# frozen_string_literal: true

module ::Blog
  module GuardianExtensions
    def can_edit_post?(post)
      if post.is_first_post? && post.topic&.blog_published_discussion?
        return(
          Thread.current[:blog_publishing_topic] == post.topic_id &&
            Configuration.publisher?(user) && can_see?(post.topic)
        )
      end
      if post.is_first_post? && can_edit_blog_draft?(post.topic) && !post.hidden? &&
           !post.deleted_at && (!post.locked? || is_staff?)
        return true
      end
      super
    end

    def can_edit_topic?(topic)
      if topic&.blog_published_discussion?
        return(
          Thread.current[:blog_publishing_topic] == topic.id && Configuration.publisher?(user) &&
            can_see?(topic)
        )
      end
      return true if can_edit_blog_draft?(topic) && (!topic.first_post&.locked? || is_staff?)
      super
    end

    private

    def can_edit_blog_draft?(topic)
      topic&.blog_editorial_draft? && Configuration.contributor?(user) &&
        (Configuration.editor?(user) || topic.user_id == user.id) && can_see?(topic)
    end
  end
end
