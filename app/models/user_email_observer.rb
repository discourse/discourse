class UserEmailObserver < ActiveRecord::Observer
  observe :notification

  def after_commit(notification)
    if notification.send(:transaction_include_action?, :create)
      notification_type = Notification.types[notification.notification_type]

      # Delegate to email_user_{{NOTIFICATION_TYPE}} if exists
      email_method = :"email_user_#{notification_type.to_s}"
      send(email_method, notification) if respond_to?(email_method)
    end
  end

  def email_user_mentioned(notification)
    return unless notification.user.email_direct?
    Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes,
                   :user_email,
                   type: :user_mentioned,
                   user_id: notification.user_id,
                   notification_id: notification.id)
  end

  def email_user_posted(notification)
    return unless notification.user.email_direct?
    Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes,
                   :user_email,
                   type: :user_posted,
                   user_id: notification.user_id,
                   notification_id: notification.id)
  end

  def email_user_quoted(notification)
    return unless notification.user.email_direct?
    Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes,
                   :user_email,
                   type: :user_quoted,
                   user_id: notification.user_id,
                   notification_id: notification.id)
  end

  def email_user_replied(notification)
    return unless notification.user.email_direct?
    Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes,
                    :user_email,
                    type: :user_replied,
                    user_id: notification.user_id,
                    notification_id: notification.id)
  end

  def email_user_invited_to_private_message(notification)
    return unless notification.user.email_direct?
    Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes,
                   :user_email,
                   type: :user_invited_to_private_message,
                   user_id: notification.user_id,
                   notification_id: notification.id)
  end
end
