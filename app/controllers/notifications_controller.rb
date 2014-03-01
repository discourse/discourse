class NotificationsController < ApplicationController

  before_filter :ensure_logged_in

  def index
    notifications = Notification.recent_report(current_user, 10)

    current_user.saw_notification_id(notifications.first.id) if notifications.present?
    current_user.reload
    current_user.publish_notifications_state

    render_serialized(notifications, NotificationSerializer)
  end

end
