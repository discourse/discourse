require_dependency 'email/sender'

module Jobs

  # Asynchronously send an email to a user
  class UserEmail < Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      raise Discourse::InvalidParameters.new(:type)    unless args[:type].present?

      post = nil
      notification = nil
      type = args[:type]
      user = User.find_by(id: args[:user_id])
      to_address = args[:to_address].presence || user.try(:email).presence || "no_email_found"

      set_skip_context(type, args[:user_id], to_address, args[:post_id])

      return skip(I18n.t("email_log.no_user", user_id: args[:user_id])) unless user

      if args[:post_id].present?
        post = Post.find_by(id: args[:post_id])
        return skip(I18n.t('email_log.post_not_found', post_id: args[:post_id])) unless post.present?
      end

      if args[:notification_id].present?
        notification = Notification.find_by(id: args[:notification_id])
      end

      message, skip_reason = message_for_email(user,
                                               post,
                                               type,
                                               notification,
                                               args[:notification_type],
                                               args[:notification_data_hash],
                                               args[:email_token],
                                               args[:to_address])

      if message
        Email::Sender.new(message, type, user).send
      else
        skip_reason
      end
    end

    def set_skip_context(type, user_id, to_address, post_id)
      @skip_context = { type: type, user_id: user_id, to_address: to_address, post_id: post_id }
    end

    NOTIFICATIONS_SENT_BY_MAILING_LIST ||= Set.new %w{
      posted
      replied
      mentioned
      group_mentioned
      quoted
    }

    CRITICAL_EMAIL_TYPES = Set.new %i{
      account_created
      admin_login
      confirm_new_email
      confirm_old_email
      forgot_password
      notify_old_email
      signup
      signup_after_approval
    }

    def message_for_email(user, post, type, notification,
                         notification_type=nil, notification_data_hash=nil,
                         email_token=nil, to_address=nil)

      set_skip_context(type, user.id, to_address || user.email, post.try(:id))

      return skip_message(I18n.t("email_log.anonymous_user"))   if user.anonymous?
      return skip_message(I18n.t("email_log.suspended_not_pm")) if user.suspended? && type != :user_private_message

      return if user.staged && type == :digest

      seen_recently = (user.last_seen_at.present? && user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago)
      seen_recently = false if user.user_option.email_always || user.staged

      email_args = {}

      if post || notification || notification_type
        return skip_message(I18n.t('email_log.seen_recently')) if seen_recently && !user.suspended?
      end

      if post
        email_args[:post] = post
      end

      if notification || notification_type
        email_args[:notification_type]      ||= notification_type      || notification.try(:notification_type)
        email_args[:notification_data_hash] ||= notification_data_hash || notification.try(:data_hash)

        unless String === email_args[:notification_type]
          if Numeric === email_args[:notification_type]
            email_args[:notification_type] = Notification.types[email_args[:notification_type]]
          end
          email_args[:notification_type] = email_args[:notification_type].to_s
        end

        if user.user_option.mailing_list_mode? &&
           (!post.try(:topic).try(:private_message?)) &&
           NOTIFICATIONS_SENT_BY_MAILING_LIST.include?(email_args[:notification_type])
           # no need to log a reason when the mail was already sent via the mailing list job
           return [nil, nil]
        end

        unless user.user_option.email_always?
          if (notification && notification.read?) || (post && post.seen?(user))
            return skip_message(I18n.t('email_log.notification_already_read'))
          end
        end
      end

      skip_reason = skip_email_for_post(post, user)
      return skip_message(skip_reason) if skip_reason

      # Make sure that mailer exists
      raise Discourse::InvalidParameters.new("type=#{type}") unless UserNotifications.respond_to?(type)

      if email_token.present?
        email_args[:email_token] = email_token
      end

      if type == :notify_old_email
        email_args[:new_email] = user.email
      end

      if EmailLog.reached_max_emails?(user)
        return skip_message(I18n.t('email_log.exceeded_emails_limit'))
      end

      if !CRITICAL_EMAIL_TYPES.include?(type) && user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold
        return skip_message(I18n.t('email_log.exceeded_bounces_limit'))
      end

      message = EmailLog.unique_email_per_post(post, user) do
        UserNotifications.send(type, user, email_args)
      end

      # Update the to address if we have a custom one
      if message && to_address.present?
        message.to = to_address
      end

      [message, nil]
    end

    sidekiq_retry_in do |count, exception|
      # retry in an hour when SMTP server is busy
      # or use default sidekiq retry formula
      case exception.wrapped
      when Net::SMTPServerBusy
        1.hour + (rand(30) * (count + 1))
      else
        Jobs::UserEmail.seconds_to_delay(count)
      end
    end

    # extracted from sidekiq
    def self.seconds_to_delay(count)
      (count ** 4) + 15 + (rand(30) * (count + 1))
    end

    private

    def skip_message(reason)
      [nil, skip(reason)]
    end

    # If this email has a related post, don't send an email if it's been deleted or seen recently.
    def skip_email_for_post(post, user)
      if post
        return I18n.t('email_log.topic_nil')           if post.topic.blank?
        return I18n.t('email_log.post_user_deleted')   if post.user.blank?
        return I18n.t('email_log.post_deleted')        if post.user_deleted?
        return I18n.t('email_log.user_suspended')      if (user.suspended? && !post.user.try(:staff?))
        return I18n.t('email_log.already_read')        if PostTiming.where(topic_id: post.topic_id, post_number: post.post_number, user_id: user.id).present?
      else
        false
      end
    end

    def skip(reason)
      EmailLog.create!(
        email_type: @skip_context[:type],
        to_address: @skip_context[:to_address],
        user_id: @skip_context[:user_id],
        post_id: @skip_context[:post_id],
        skipped: true,
        skipped_reason: "[UserEmail] #{reason}",
      )
    end

  end

end
