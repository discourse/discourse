class CurrentUserSerializer < BasicUserSerializer

  attributes :name, :unread_notifications, :unread_private_messages, :admin, :notification_channel_position, :site_flagged_posts_count

  # we probably want to move this into site, but that json is cached so hanging it off current user seems okish

  def include_site_flagged_posts_count?
    object.admin
  end

  def site_flagged_posts_count
    PostAction.flagged_posts_count
  end
end
