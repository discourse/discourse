class Unread

  # This module helps us calculate unread and new post counts

  def initialize(topic, topic_user)
    @topic = topic
    @topic_user = topic_user
  end


  def unread_posts
    return 0 if do_not_notify?(@topic_user.notification_level)
    result = ((@topic_user.seen_post_count||0) - (@topic_user.last_read_post_number||0))
    result = 0 if result < 0
    result
  end

  def new_posts
    return 0 if @topic_user.seen_post_count.blank?
    return 0 if do_not_notify?(@topic_user.notification_level)

    new_posts = (@topic.highest_post_number - @topic_user.seen_post_count)
    new_posts = 0 if new_posts < 0
    return new_posts
  end

  protected

  def do_not_notify?(notification_level)
    [TopicUser.notification_levels[:muted], TopicUser.notification_levels[:regular]].include?(notification_level)
  end

end
