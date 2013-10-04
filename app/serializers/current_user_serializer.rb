class CurrentUserSerializer < BasicUserSerializer

  attributes :name,
             :unread_notifications,
             :unread_private_messages,
             :admin?,
             :notification_channel_position,
             :site_flagged_posts_count,
             :moderator?,
             :staff?,
             :reply_count,
             :topic_count,
             :enable_quoting,
             :external_links_in_new_tab,
             :dynamic_favicon,
             :trust_level,
             :can_edit

  def include_site_flagged_posts_count?
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

end
