class NotificationsController < ApplicationController

  before_filter :ensure_logged_in

  def index
    notifications = current_user.notifications.recent.includes(:topic).all
    current_user.saw_notification_id(notifications.first.id) if notifications.present?
    current_user.reload
    current_user.publish_notifications_state

    render_serialized(notifications, NotificationSerializer)
  end

end
