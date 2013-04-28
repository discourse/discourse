class CurrentUserSerializer < BasicUserSerializer

  attributes :name,
             :unread_notifications,
             :unread_private_messages,
             :admin?,
             :notification_channel_position,
             :site_flagged_posts_count,
             :moderator?,
             :reply_count,
             :topic_count,
             :enable_quoting,
             :external_links_in_new_tab,
             :trust_level

  # we probably want to move this into site, but that json is cached so hanging it off current user seems okish

  def include_site_flagged_posts_count?
    object.admin
  end

  def topic_count
    object.topics.count
  end

  def reply_count
    object.posts.where("post_number > 1").count
  end

  def moderator?
    object.moderator?
  end

  def site_flagged_posts_count
    PostAction.flagged_posts_count
  end

end
