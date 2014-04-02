class CurrentUserSerializer < BasicUserSerializer

  attributes :name,
             :unread_notifications,
             :unread_private_messages,
             :admin,
             :notification_channel_position,
             :site_flagged_posts_count,
             :moderator,
             :staff,
             :reply_count,
             :topic_count,
             :enable_quoting,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :trust_level,
             :can_edit,
             :can_invite_to_forum,
             :no_password,
             :can_delete_account,
             :should_be_redirected_to_top,
             :redirected_to_top_reason

  def staff
    object.staff?
  end

  def topic_count
    object.topics.count
  end

  def reply_count
    object.user_stat.topic_reply_count
  end

  def site_flagged_posts_count
    PostAction.flagged_posts_count
  end

  def can_edit
    true
  end

  def can_invite_to_forum
    true
  end

  def no_password
    true
  end

  def can_delete_account
    true
  end

  def filter(keys)
    keys.delete(:site_flagged_posts_count) unless object.staff?
    keys.delete(:can_invite_to_forum) unless scope.can_invite_to_forum?
    keys.delete(:no_password) if object.has_password?
    keys.delete(:can_delete_account) unless scope.can_delete_user?(object)
    keys.delete(:redirected_to_top_reason) unless object.should_be_redirected_to_top
    super(keys)
  end

end
