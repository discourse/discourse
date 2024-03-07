# frozen_string_literal: true

class CurrentUserCountsSerializer < BasicUserSerializer
  attributes :unread_notifications,
             :unread_pm_notifications,
             :unseen_reviewables,
             :topic_tracking_counts,
             :group_inboxes_counts,
             def include_name?
               false
             end

  def unread_notifications
    object.all_unread_notifications_count
  end

  def unread_pm_notifications
    object.new_personal_messages_notifications_count
  end

  def unseen_reviewables
    Reviewable.unseen_reviewable_count(object)
  end

  def topic_tracking_counts
    object.topic_tracking_counts
  end

  def include_group_inboxes_counts?
    scope.user.staff?
  end

  def group_inboxes_counts
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

  # needs chat
end
