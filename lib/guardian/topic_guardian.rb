#mixin for all guardian methods dealing with topic permisions
module TopicGuardian
  # Can the user create a topic in the forum
  def can_create?(klass, parent=nil)
    return false unless authenticated? && klass

    # If no parent is provided, we look for a can_i_create_klass?
    # custom method.
    #
    # If a parent is provided, we look for a method called
    # can_i_create_klass_on_parent?
    target = klass.name.underscore
    if parent.present?
      return false unless can_see?(parent)
      target << "_on_#{parent.class.name.underscore}"
    end
    create_method = :"can_create_#{target}?"

    return send(create_method, parent) if respond_to?(create_method)

    true
  end

  def can_remove_allowed_users?(topic)
    is_staff?
  end

  # Creating Methods
  def can_create_topic?(parent)
    user &&
    user.trust_level >= SiteSetting.min_trust_to_create_topic.to_i &&
    can_create_post?(parent)
  end

  def can_create_topic_on_category?(category)
    can_create_topic?(nil) &&
    (!category || Category.topic_create_allowed(self).where(:id => category.id).count == 1)
  end

  def can_create_post_on_topic?(topic)
    # No users can create posts on deleted topics
    return false if topic.trashed?

    is_staff? || (not(topic.closed? || topic.archived? || topic.trashed?) && can_create_post?(topic))
  end

  # Editing Method
  def can_edit_topic?(topic)
    !topic.archived && (is_staff? || is_my_own?(topic) || user.has_trust_level?(:leader))
  end

  # Recovery Method
  def can_recover_topic?(topic)
    is_staff?
  end

  def can_delete_topic?(topic)
    !topic.trashed? &&
    is_staff? &&
    !(Category.exists?(topic_id: topic.id))
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

      # NOTE
      # At the moment staff can see PMs, there is some talk of restricting this, however
      # we still need to allow staff to join PMs for the case of flagging ones

      # not private, or I am allowed (or is staff)
      (not(topic.private_message?) || authenticated? && (topic.all_allowed_users.where(id: @user.id).exists? || is_staff?))
    end
  end
end
