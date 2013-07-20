module TopicGuardian
  def can_create_topic?(parent)
    can_create_post?(parent)
  end

  def can_create_topic_on_category?(category)
    can_create_post?(nil) && (
      !category ||
      Category.topic_create_allowed(self).where(:id => category.id).count == 1
    )
  end

  def can_edit_topic?(topic)
    !topic.archived && (is_staff? || is_my_own?(topic))
  end

  def can_delete_topic?(topic)
    !topic.trashed? &&
    is_staff? &&
    !(Category.exists?(topic_id: topic.id))
  end

  def can_recover_topic?(topic)
    is_staff?
  end

  def can_reply_as_new_topic?(topic)
    authenticated? && topic && not(topic.private_message?) && @user.has_trust_level?(:basic)
  end

  def can_see_topic?(topic)
    if topic
      is_staff? ||

      topic.deleted_at.nil? &&

      # not secure, or I can see it
      (not(topic.read_restricted_category?) || can_see_category?(topic.category)) &&

      # not private, or I am allowed (or an admin)
      (not(topic.private_message?) || authenticated? && (topic.all_allowed_users.where(id: @user.id).exists? || is_admin?))
    end
  end

  def can_create_post_on_topic?(topic)
    # No users can create posts on deleted topics
    return false if topic.trashed?

    is_staff? || (not(topic.closed? || topic.archived? || topic.trashed?) && can_create_post?(topic))
  end

  def can_remove_allowed_users?(topic)
    is_staff?
  end
end
