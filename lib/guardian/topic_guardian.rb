#mixin for all guardian methods dealing with topic permisions
module TopicGuardian

  def can_remove_allowed_users?(topic)
    is_staff?
  end

  # Creating Methods
  def can_create_topic?(parent)
    is_staff? ||
    (user &&
      user.trust_level >= SiteSetting.min_trust_to_create_topic.to_i &&
      can_create_post?(parent))
  end

  def can_create_topic_on_category?(category)
    can_create_topic?(nil) &&
    (!category || Category.topic_create_allowed(self).where(id: category.id).count == 1)
  end

  def can_create_post_on_topic?(topic)
    # No users can create posts on deleted topics
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
    return true if (topic.archived && !topic.private_message? && user.has_trust_level?(TrustLevel[4]) && can_create_post?(topic))

    # TL3 users can not edit archived topics and private messages
    return true if (!topic.archived && !topic.private_message? && user.has_trust_level?(TrustLevel[3]) && can_create_post?(topic))

    return false if topic.archived
    is_my_own?(topic) && !topic.edit_time_limit_expired?
  end

  # Recovery Method
  def can_recover_topic?(topic)
    is_staff?
  end

  def can_delete_topic?(topic)
    !topic.trashed? &&
    is_staff? &&
    !(Category.exists?(topic_id: topic.id)) &&
    !Discourse.static_doc_topic_ids.include?(topic.id)
  end

  def can_convert_topic?(topic)
    return false if topic && topic.trashed?
    return true if is_admin?
    is_moderator? && can_create_post?(topic)
  end

  def can_reply_as_new_topic?(topic)
    authenticated? && topic && not(topic.private_message?) && @user.has_trust_level?(TrustLevel[1])
  end

  def can_see_deleted_topics?
    is_staff?
  end

  def can_see_topic?(topic)
    return false unless topic
    # Admins can see everything
    return true if is_admin?
    # Deleted topics
    return false if topic.deleted_at && !can_see_deleted_topics?

    if topic.private_message?
      return authenticated? &&
             topic.all_allowed_users.where(id: @user.id).exists?
    end

    # not secure, or I can see it
    !topic.read_restricted_category? || can_see_category?(topic.category)
  end

  def can_see_topic_if_not_deleted?(topic)
    return false unless topic
    # Admins can see everything
    return true if is_admin?
    # Deleted topics
    # return false if topic.deleted_at && !can_see_deleted_topics?

    if topic.private_message?
      return authenticated? &&
        topic.all_allowed_users.where(id: @user.id).exists?
    end

    # not secure, or I can see it
    !topic.read_restricted_category? || can_see_category?(topic.category)
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

end
