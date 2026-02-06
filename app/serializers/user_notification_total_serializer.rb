# frozen_string_literal: true

class UserNotificationTotalSerializer < ApplicationSerializer
  attributes :username,
             :unread_notifications,
             :unread_personal_messages,
             :unseen_reviewables,
             :topic_tracking,
             :group_inboxes

  def unread_notifications
    object.all_unread_notifications_count - new_personal_messages_notifications_count
  end

  def include_unread_personal_messages?
    object.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)
  end

  def unread_personal_messages
    new_personal_messages_notifications_count
  end

  def include_unseen_reviewables?
    scope.user.staff?
  end

  def unseen_reviewables
    Reviewable.unseen_reviewable_count(object)
  end

  def topic_tracking
    TopicTrackingState.report_totals(object)
  end

  def group_inboxes
    notifications =
      object.notification_query.list(
        filter: :unread,
        types: [Notification.types[:group_message_summary]],
      )

    notifications.filter_map do |n|
      data = n.data_hash
      { group_id: data[:group_id], group_name: data[:group_name], count: data[:inbox_count] }
    end
  end

  def new_personal_messages_notifications_count
    @new_personal_messages_notifications_count ||= object.new_personal_messages_notifications_count
  end
end
