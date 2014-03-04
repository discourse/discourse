class NotificationsController < ApplicationController

  before_filter :ensure_logged_in, except: [:set_from_email]
  skip_before_filter :check_xhr, only: [:set_from_email]

  def index
    notifications = Notification.recent_report(current_user, 10)

    current_user.saw_notification_id(notifications.first.id) if notifications.present?
    current_user.reload
    current_user.publish_notifications_state

    render_serialized(notifications, NotificationSerializer)
  end

  def set_from_email
    new_level = params[:notification_level].to_i
    email_log = EmailLog.for(params[:reply_key])
    @topic = email_log.topic
    TopicUser.change(email_log.user, @topic.id,
        notification_level: new_level)
    @notification_level = TopicUser.notification_levels[new_level]
    render layout: 'no_js'
  end

end
