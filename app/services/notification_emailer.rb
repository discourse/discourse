# frozen_string_literal: true

class NotificationEmailer

  class EmailUser
    attr_reader :notification

    def initialize(notification)
      @notification = notification
    end

    def group_mentioned
      enqueue :group_mentioned
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

    def linked
      enqueue :user_linked
    end

    def watching_first_post
      enqueue :user_watching_first_post
    end

    def private_message
      enqueue_private(:user_private_message)
    end

    def invited_to_private_message
      enqueue(:user_invited_to_private_message, private_delay)
    end

    def invited_to_topic
      enqueue(:user_invited_to_topic, private_delay)
    end

    def self.notification_params(notification, type)
      post_id = (notification.data_hash[:original_post_id] || notification.post_id).to_i

      hash = {
        type: type,
        user_id: notification.user_id,
        notification_id: notification.id,
        notification_data_hash: notification.data_hash,
        notification_type: Notification.types[notification.notification_type],
      }

      hash[:post_id] = post_id if post_id > 0
      hash
    end

    private

    EMAILABLE_POST_TYPES ||= Set.new [Post.types[:regular], Post.types[:whisper]]

    def enqueue(type, delay = default_delay)
      return if notification.user.user_option.email_level == UserOption.email_level_types[:never]
      perform_enqueue(type, delay)
    end

    def enqueue_private(type, delay = private_delay)

      if notification.user.user_option.nil?
        # this can happen if we roll back user creation really early
        # or delete user
        # bypass this pm
        return
      end

      return if notification.user.user_option.email_messages_level == UserOption.email_level_types[:never]
      perform_enqueue(type, delay)
    end

    def perform_enqueue(type, delay)
      user = notification.user
      return unless user.active? || user.staged?
      return if SiteSetting.must_approve_users? && !user.approved? && !user.staged?

      return unless EMAILABLE_POST_TYPES.include?(post_type)

      Jobs.enqueue_in(delay, :user_email, self.class.notification_params(notification, type))
    end

    def default_delay
      SiteSetting.email_time_window_mins.minutes
    end

    def private_delay
      SiteSetting.personal_email_time_window_seconds
    end

    def post_type
      @post_type ||= begin
        type = notification.data_hash["original_post_type"] if notification.data_hash
        type ||= notification.post.try(:post_type)
        type
      end
    end

  end

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.process_notification(notification)
    return if @disabled

    email_user   = EmailUser.new(notification)
    email_method = Notification.types[notification.notification_type]

    email_user.public_send(email_method) if email_user.respond_to? email_method
  end

end
