require_dependency 'notification_serializer'

class NotificationsController < ApplicationController

  before_filter :ensure_logged_in

  def index
    user = current_user
    if params[:recent].present?

      limit = (params[:limit] || 15).to_i
      limit = 50 if limit > 50

      notifications = Notification.recent_report(current_user, limit)

      if notifications.present?
        # ordering can be off due to PMs
        max_id = notifications.map(&:id).max
        current_user.saw_notification_id(max_id) unless params.has_key?(:silent)
      end
      current_user.reload
      current_user.publish_notifications_state

      render_serialized(notifications, NotificationSerializer, root: :notifications)
    else
      offset = params[:offset].to_i
      user = User.find_by_username(params[:username].to_s) if params[:username]

      guardian.ensure_can_see_notifications!(user)

      notifications = Notification.where(user_id: user.id)
                                  .visible
                                  .includes(:topic)
                                  .order(created_at: :desc)

      total_rows = notifications.dup.count
      notifications = notifications.offset(offset).limit(60)
      render_json_dump(notifications: serialize_data(notifications, NotificationSerializer),
                       total_rows_notifications: total_rows,
                       load_more_notifications: notifications_path(username: user.username, offset: offset + 60))
    end

  end

  def mark_read
    Notification.where(user_id: current_user.id).includes(:topic).where(read: false).update_all(read: true)

    current_user.saw_notification_id(Notification.recent_report(current_user, 1).max)
    current_user.reload
    current_user.publish_notifications_state

    render json: success_json
  end

end
