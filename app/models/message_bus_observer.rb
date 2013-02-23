require_dependency 'message_bus'
require_dependency 'discourse_observer'

# This class is responsible for notifying the message bus of various
# events.
class MessageBusObserver < DiscourseObserver
  observe :post, :notification, :user_action, :topic

  def after_create_post(post)
    MessageBus.publish("/topic/#{post.topic_id}",
                        id: post.id,
                        created_at: post.created_at,
                        user: BasicUserSerializer.new(post.user).as_json(root: false),
                        post_number: post.post_number)
  end

  def after_create_notification(notification)
    refresh_notification_count(notification)
  end

  def after_destroy_notification(notification)
    refresh_notification_count(notification)
  end

  def after_create_user_action(user_action)
    MessageBus.publish("/users/#{user_action.user.username.downcase}", user_action.id)
  end

  def after_create_topic(topic)

    # Don't publish invisible topics
    return unless topic.visible?

    return if topic.private_message?

    topic.posters = topic.posters_summary
    topic.posts_count = 1
    topic_json = TopicListItemSerializer.new(topic).as_json
    MessageBus.publish("/popular", topic_json)

    # If it has a category, add it to the category views too
    if topic.category.present?
      MessageBus.publish("/category/#{topic.category.slug}", topic_json)
    end

  end

  protected

    def refresh_notification_count(notification)
      user_id = notification.user.id
      MessageBus.publish("/notification/#{user_id}",
        {unread_notifications: notification.user.unread_notifications,
         unread_private_messages: notification.user.unread_private_messages},
        user_ids: [user_id] # only publish the notification to this user
      )
    end
end
