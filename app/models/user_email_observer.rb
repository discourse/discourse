class UserEmailObserver < ActiveRecord::Observer
  observe :notification

  class EmailUser
    attr_reader :notification

    def initialize(notification)
      @notification = notification
    end

    def mentioned
      enqueue :user_mentioned
    end

    def posted
      enqueue :user_posted
    end

    def quoted
      enqueue :user_quoted
    end

    def replied
      enqueue :user_replied
    end

    def private_message
      enqueue_private :user_private_message
    end

    def invited_to_private_message
      enqueue :user_invited_to_private_message
    end

    def invited_to_topic
      enqueue :user_invited_to_topic
    end

    private

    def enqueue(type)
      return unless (notification.user.email_direct? && notification.user.active?)

      Jobs.enqueue_in(delay,
                     :user_email,
                     type: type,
                     user_id: notification.user_id,
                     notification_id: notification.id)
    end

    def enqueue_private(type)
      return unless (notification.user.email_private_messages? && notification.user.active?)

      Jobs.enqueue_in(delay,
                      :user_email,
                      type: type,
                      user_id: notification.user_id,
                      notification_id: notification.id)
    end

    def delay
      SiteSetting.email_time_window_mins.minutes
    end
  end

  def after_commit(notification)
    transaction_includes_action = notification.send(:transaction_include_any_action?, [:create])

    delegate_to_email_user notification if transaction_includes_action
  end

  private


  def extract_notification_type(notification)
    Notification.types[notification.notification_type]
  end

  def delegate_to_email_user(notification)
    email_user   = EmailUser.new(notification)
    email_method = extract_notification_type notification

    email_user.send(email_method) if email_user.respond_to? email_method
  end
end
