# frozen_string_literal: true

module ::Blog
  module GuardianExtensions
    def can_edit_post?(post)
      return super if !post.is_first_post?
      topic = post.topic
      return false if topic&.blog_published_discussion?
      return true if can_edit_blog_draft_post?(post)
      super
    end

    def can_edit_topic?(topic)
      return false if topic&.blog_published_discussion?
      return true if can_edit_blog_draft_topic?(topic)
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
    def can_edit_blog_topic?(topic)
      return false if !is_blog_contributor?
      return false if !can_see?(topic)
      return false if !is_blog_editor? && topic.user_id != user.id
      blog_article_topic?(topic)
    end

    def can_publish_blog_topic?(topic)
      is_blog_publisher? && can_edit_blog_topic?(topic)
    end

    private

    def can_edit_blog_draft_post?(post)
      return false if !can_edit_blog_draft?(post.topic)
      return false if post.hidden?
      return false if post.deleted_at
      !post.locked? || is_staff?
    end

    def can_edit_blog_draft_topic?(topic)
      return false if !can_edit_blog_draft?(topic)
      return false if topic.first_post&.hidden?
      !topic.first_post&.locked? || is_staff?
    end

    def can_edit_blog_draft?(topic)
      return false if !topic&.blog_editorial_draft?
      return false if !is_blog_contributor?
      return false if !is_blog_editor? && topic.user_id != user.id
      return false if !can_see?(topic)
      valid_blog_drafts_category?(topic.category)
    end

    def valid_blog_drafts_category?(category)
      cache = (@valid_blog_drafts_categories ||= {})
      return cache[category.id] if cache.key?(category.id)
      cache[category.id] = Blog::Readiness.valid_drafts_category?(category)
    end

    def blog_role_user?
      return false if !UpcomingChanges.enabled?(:blog_enabled)
      return false if !authenticated?
      return false if !user.active?
      return false if user.suspended?
      !user.silenced?
    end

    def in_blog_role_groups?(group_ids)
      return true if group_ids.include?(Group::AUTO_GROUPS[:staff]) && is_staff?
      return true if group_ids.include?(Group::AUTO_GROUPS[:admins]) && is_admin?
      return true if group_ids.include?(Group::AUTO_GROUPS[:moderators]) && is_moderator?
      user.in_any_groups?(group_ids - Group::AUTO_GROUPS.values_at(:staff, :admins, :moderators))
    end

    def blog_article_topic?(topic)
      categories = [SiteSetting.blog_category.to_i, SiteSetting.blog_drafts_category.to_i]
      return false if topic.private_message?
      return false if topic.shared_draft?
      return false if !categories.include?(topic.category_id)
      return false if topic.category&.topic_id == topic.id
      return false if topic.deleted_at
      topic.visible
    end
  end
end
