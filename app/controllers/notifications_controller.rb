class NotificationsController < ApplicationController

  before_filter :ensure_logged_in

  def recent
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

  def history
    params.permit(:before, :user)
    params[:before] ||= 1.day.from_now

    user = current_user
    if params[:user]
      user = User.find_by_username(params[:user].to_s)
    end

    unless guardian.can_see_notifications?(user)
      return render json: {errors: [I18n.t('js.errors.reasons.forbidden')]}, status: 403
    end

    notifications = Notification.where(user_id: user.id)
        .includes(:topic)
        .limit(60)
        .where('created_at < ?', params[:before])
        .order(created_at: :desc)

    render_serialized(notifications, NotificationSerializer)
  end

  def reset_new
    params.permit(:user)

    user = current_user
    if params[:user]
      user = User.find_by_username(params[:user].to_s)
    end

    Notification.where(user_id: user.id).includes(:topic).where(read: false).update_all(read: true)

    current_user.saw_notification_id(Notification.recent_report(current_user, 1).max)
    current_user.reload
    current_user.publish_notifications_state

    render nothing: true
  end
end
