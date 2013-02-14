class CurrentUserSerializer < BasicUserSerializer

  attributes :name, 
             :unread_notifications, 
             :unread_private_messages, 
             :admin?, 
             :notification_channel_position, 
             :site_flagged_posts_count,
             :moderator?,
             :post_count

  # we probably want to move this into site, but that json is cached so hanging it off current user seems okish

  def include_site_flagged_posts_count?
    object.admin
  end

  def post_count
    object.posts.count
  end

  def moderator?
    object.has_trust_level?(:moderator)
  end

  def site_flagged_posts_count
    PostAction.flagged_posts_count
  end
end
