# frozen_string_literal: true

module UserTagNotificationsMixin
  def muted_tags
    tags_with_notification_level(:muted)
  end

  def tracked_tags
    tags_with_notification_level(:tracking)
  end

  def watching_first_post_tags
    tags_with_notification_level(:watching_first_post)
  end

  def watched_tags
    tags_with_notification_level(:watching)
  end

  def regular_tags
    tags_with_notification_level(:regular)
  end

  def tags_with_notification_level(lookup_level)
    tag_user_notification_levels
      .select { |id, level| level == TagUser.notification_levels[lookup_level] }
      .keys
  end

  def tag_user_notification_levels
    @tag_user_notification_levels ||= TagUser.notification_levels_for(user)
  end
end
