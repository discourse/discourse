# frozen_string_literal: true

class Unread
  # This module helps us calculate unread post counts

  def initialize(topic, topic_user, guardian)
    @guardian = guardian
    @topic = topic
    @topic_user = topic_user
  end

  def unread_posts
    return 0 if @topic_user.last_read_post_number.blank?
    return 0 if do_not_notify?(@topic_user.notification_level)

    highest_post_number =
      @guardian.is_whisperer? ? @topic.highest_staff_post_number : @topic.highest_post_number

    return 0 if @topic_user.last_read_post_number > highest_post_number

    unread = (highest_post_number - @topic_user.last_read_post_number)
    unread = 0 if unread < 0
    unread
  end

  protected

  DO_NOT_NOTIFY_LEVELS = [
    TopicUser.notification_levels[:muted],
    TopicUser.notification_levels[:regular],
  ].freeze

  def do_not_notify?(notification_level)
    DO_NOT_NOTIFY_LEVELS.include?(notification_level)
  end
end
