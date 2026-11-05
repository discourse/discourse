# frozen_string_literal: true

module ::Blog
  module GuardianExtensions
    def can_edit_post?(post)
      if post.is_first_post? && post.topic&.blog_published_discussion?
        return(
          Thread.current[:blog_publishing_topic] == post.topic_id && is_blog_publisher? &&
            can_see?(post.topic)
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
          Thread.current[:blog_publishing_topic] == topic.id && is_blog_publisher? &&
            can_see?(topic)
        )
      end
      return true if can_edit_blog_draft?(topic) && (!topic.first_post&.locked? || is_staff?)
      super
    end

    # Each role includes the ones below it: publisher, editor, contributor.
    def is_blog_publisher?
      blog_role_user? && (is_admin? || in_blog_role_groups?(SiteSetting.blog_publisher_groups_map))
    end

    def is_blog_editor?
      is_blog_publisher? ||
        (blog_role_user? && in_blog_role_groups?(SiteSetting.blog_editor_groups_map))
    end

    def is_blog_contributor?
      is_blog_editor? ||
        (blog_role_user? && in_blog_role_groups?(SiteSetting.blog_contributor_groups_map))
    end

    # Editorial work on an article's working copy or its Blog-category topic.
    # Contributors may only work on articles they started.
    def can_edit_blog_topic?(topic)
      is_blog_contributor? && can_see?(topic) && (is_blog_editor? || topic.user_id == user.id) &&
        blog_article_topic?(topic)
    end

    def can_publish_blog_topic?(topic)
      is_blog_publisher? && can_edit_blog_topic?(topic)
    end

    private

    def can_edit_blog_draft?(topic)
      topic&.blog_editorial_draft? && is_blog_contributor? &&
        (is_blog_editor? || topic.user_id == user.id) && can_see?(topic)
    end

    def blog_role_user?
      UpcomingChanges.enabled?(:blog_enabled) && authenticated? && user.active? &&
        !user.suspended? && !user.silenced?
    end

    def in_blog_role_groups?(group_ids)
      return true if group_ids.include?(Group::AUTO_GROUPS[:staff]) && is_staff?
      return true if group_ids.include?(Group::AUTO_GROUPS[:admins]) && is_admin?
      return true if group_ids.include?(Group::AUTO_GROUPS[:moderators]) && is_moderator?
      user.in_any_groups?(group_ids - Group::AUTO_GROUPS.values_at(:staff, :admins, :moderators))
    end

    def blog_article_topic?(topic)
      categories = [SiteSetting.blog_category.to_i, SiteSetting.blog_drafts_category.to_i]
      !topic.private_message? && !topic.shared_draft? && categories.include?(topic.category_id) &&
        topic.category&.topic_id != topic.id && !topic.deleted_at && topic.visible
    end
  end
end
