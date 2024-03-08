# frozen_string_literal: true

class CurrentUserCountSerializer < BasicUserSerializer
  attributes :unread_notifications,
             :unread_personal_messages,
             :unseen_reviewables,
             :topic_tracking,
             :group_inboxes,
             def unread_notifications
               object.all_unread_notifications_count -
                 object.new_personal_messages_notifications_count
             end

  def unread_personal_messages
    object.new_personal_messages_notifications_count
  end

  def unseen_reviewables
    Reviewable.unseen_reviewable_count(object)
  end

  def topic_tracking
    object.topic_tracking_counts
  end

  def include_group_inboxes?
    scope.user.staff?
  end

  def group_inboxes
    group_inbox_data =
      Notification
        .unread
        .where(
          user_id: scope.user.id,
          notification_type: Notification.types[:group_message_summary],
        )
        .pluck(:data)
        .to_a

    results = []

    return results if group_inbox_data.blank?

    group_inbox_data.map do |json|
      data = JSON.parse(json, symbolize_names: true)

      results << {
        group_id: data[:group_id],
        group_name: data[:group_name],
        count: data[:inbox_count],
      }
    end

    results
  end
end
