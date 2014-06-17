class NotificationsController < ApplicationController

  before_filter :ensure_logged_in

  def index
    notifications = Notification.recent_report(current_user, 10)

    if notifications.present?
      # ordering can be off due to PMs
      max_id = notifications.map(&:id).max
      current_user.saw_notification_id(max_id) unless params.has_key?(:silent)
    end
    current_user.reload
    current_user.publish_notifications_state

    render_serialized(notifications, NotificationSerializer)
  end

end
