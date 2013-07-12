class NotificationsController < ApplicationController

  before_filter :ensure_logged_in

  def index
    notifications = current_user.notifications.recent.includes(:topic)

    if notifications.present?
      notifications += current_user.notifications
        .order('created_at desc')
        .where(read: false, notification_type: Notification.types[:private_message])
        .where('id < ?', notifications.last.id)
        .limit(5)
    end

    notifications = notifications.to_a
    current_user.saw_notification_id(notifications.first.id) if notifications.present?
    current_user.reload
    current_user.publish_notifications_state

    render_serialized(notifications, NotificationSerializer)
  end

end
