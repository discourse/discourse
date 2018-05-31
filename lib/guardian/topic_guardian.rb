#mixin for all guardian methods dealing with topic permisions
module TopicGuardian

  def can_remove_allowed_users?(topic, target_user = nil)
    is_staff? ||
    (
      topic.allowed_users.count > 1 &&
      topic.user != target_user &&
      !!(target_user && user == target_user)
    )
  end

  def can_create_shared_draft?
    is_staff? && SiteSetting.shared_drafts_enabled?
  end

  def can_publish_topic?(topic, category)
    is_staff? && can_see?(topic) && can_create_topic?(category)
  end

  # Creating Methods
  def can_create_topic?(parent)
    is_staff? ||
    (user &&
      user.trust_level >= SiteSetting.min_trust_to_create_topic.to_i &&
      can_create_post?(parent))
  end

  def can_create_topic_on_category?(category)
    # allow for category to be a number as well
    category_id = Category === category ? category.id : category

    can_create_topic?(nil) &&
    (!category || Category.topic_create_allowed(self).where(id: category_id).count == 1)
  end

  def can_create_post_on_topic?(topic)
    # No users can create posts on deleted topics
    return false if topic.blank?
    return false if topic.trashed?
    return true if is_admin?

    trusted = (authenticated? && user.has_trust_level?(TrustLevel[4])) || is_moderator?

    (!(topic.closed? || topic.archived?) || trusted) && can_create_post?(topic)
  end

  # Editing Method
  def can_edit_topic?(topic)
    return false if Discourse.static_doc_topic_ids.include?(topic.id) && !is_admin?
    return false unless can_see?(topic)

    return true if is_admin?
    return true if is_moderator? && can_create_post?(topic)

    # can't edit topics in secured categories where you don't have permission to create topics
    return false if !can_create_topic_on_category?(topic.category)

    # TL4 users can edit archived topics, but can not edit private messages
    return true if (
      SiteSetting.trusted_users_can_edit_others? &&
      topic.archived &&
      !topic.private_message? &&
      user.has_trust_level?(TrustLevel[4]) &&
      can_create_post?(topic)
    )

    # TL3 users can not edit archived topics and private messages
    return true if (
      SiteSetting.trusted_users_can_edit_others? &&
      !topic.archived &&
      !topic.private_message? &&
      user.has_trust_level?(TrustLevel[3]) &&
      can_create_post?(topic)
    )

    return false if topic.archived
    is_my_own?(topic) && !topic.edit_time_limit_expired?
  end

  # Recovery Method
  def can_recover_topic?(topic)
    topic && topic.deleted_at && topic.user && is_staff?
  end

  def can_delete_topic?(topic)
    !topic.trashed? &&
    is_staff? &&
    !(topic.is_category_topic?) &&
    !Discourse.static_doc_topic_ids.include?(topic.id)
  end

  def can_convert_topic?(topic)
    return false unless SiteSetting.enable_personal_messages?
    return false if topic.blank?
    return false if topic.trashed?
    return false if topic.is_category_topic?
    return true if is_admin?
    is_moderator? && can_create_post?(topic)
  end

  def can_reply_as_new_topic?(topic)
    authenticated? && topic && @user.has_trust_level?(TrustLevel[1])
  end

  def can_see_deleted_topics?
    is_staff?
  end

  def can_see_topic?(topic, hide_deleted = true)
    return false unless topic
    return true if is_admin?
    return false if hide_deleted && topic.deleted_at && !can_see_deleted_topics?

    if topic.private_message?
      return authenticated? && topic.all_allowed_users.where(id: @user.id).exists?
    end

    can_see_category?(topic.category)
  end

  def can_see_topic_if_not_deleted?(topic)
    can_see_topic?(topic, false)
  end

  def filter_allowed_categories(records)
    unless is_admin?
      allowed_ids = allowed_category_ids
      if allowed_ids.length > 0
        records = records.where('topics.category_id IS NULL or topics.category_id IN (?)', allowed_ids)
      else
        records = records.where('topics.category_id IS NULL')
      end
      records = records.references(:categories)
    end
    records
  end

  def can_edit_featured_link?(category_id)
    return false unless SiteSetting.topic_featured_link_enabled
    Category.where(id: category_id || SiteSetting.uncategorized_category_id, topic_featured_link_allowed: true).exists?
  end
end
