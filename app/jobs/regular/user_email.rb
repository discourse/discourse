require_dependency 'email/sender'
require_dependency 'user_notifications'

module Jobs

  # Asynchronously send an email to a user
  class UserEmail < Jobs::Base
    include Skippable

    sidekiq_options queue: 'low'

    # Can be overridden by subclass, for example critical email
    # should always consider being sent
    def quit_email_early?
      SiteSetting.disable_emails == 'yes'
    end

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      raise Discourse::InvalidParameters.new(:type)    unless args[:type].present?

      # This is for performance. Quit out fast without doing a bunch
      # of extra work when emails are disabled.
      return if quit_email_early?

      post = nil
      notification = nil
      type = args[:type]
      user = User.find_by(id: args[:user_id])
      to_address = args[:to_address].presence || user.try(:email).presence || "no_email_found"

      set_skip_context(type, args[:user_id], to_address, args[:post_id])

      return skip(SkippedEmailLog.reason_types[:user_email_no_user]) unless user

      if args[:post_id].present?
        post = Post.find_by(id: args[:post_id])

        unless post.present?
          return skip(SkippedEmailLog.reason_types[:user_email_post_not_found])
        end
      end

      if args[:notification_id].present?
        notification = Notification.find_by(id: args[:notification_id])
      end

      message, skip_reason_type = message_for_email(
        user,
        post,
        type,
        notification,
        args
      )

      if message
        Email::Sender.new(message, type, user).send
        if (b = user.user_stat.bounce_score) > SiteSetting.bounce_score_erode_on_send
          # erode bounce score each time we send an email
          # this means that we are punished a lot less for bounces
          # and we can recover more quickly
          user.user_stat.update(bounce_score: b - SiteSetting.bounce_score_erode_on_send)
        end
      else
        skip_reason_type
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

    def message_for_email(user, post, type, notification, args = nil)
      args ||= {}

      notification_type = args[:notification_type]
      notification_data_hash = args[:notification_data_hash]
      email_token = args[:email_token]
      to_address = args[:to_address]

      set_skip_context(type, user.id, to_address || user.email, post.try(:id))

      if user.anonymous?
        return skip_message(SkippedEmailLog.reason_types[:user_email_anonymous_user])
      end

      if user.suspended? && !["user_private_message", "account_suspended"].include?(type.to_s)
        return skip_message(SkippedEmailLog.reason_types[:user_email_user_suspended_not_pm])
      end

      return if user.staged && type.to_s == "digest"

      seen_recently = (user.last_seen_at.present? && user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago)
      seen_recently = false if user.user_option.email_always || user.staged

      email_args = {}

      if (post || notification || notification_type) &&
         (seen_recently && !user.suspended?)

        return skip_message(SkippedEmailLog.reason_types[:user_email_seen_recently])
      end

      email_args[:post] = post if post

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
           user.user_option.mailing_list_mode_frequency > 0 && # don't catch notifications for users on daily mailing list mode
           (!post.try(:topic).try(:private_message?)) &&
           NOTIFICATIONS_SENT_BY_MAILING_LIST.include?(email_args[:notification_type])
          # no need to log a reason when the mail was already sent via the mailing list job
          return [nil, nil]
        end

        unless user.user_option.email_always?
          if (notification && notification.read?) || (post && post.seen?(user))
            return skip_message(SkippedEmailLog.reason_types[:user_email_notification_already_read])
          end
        end
      end

      skip_reason_type = skip_email_for_post(post, user)
      return skip_message(skip_reason_type) if skip_reason_type.present?

      # Make sure that mailer exists
      raise Discourse::InvalidParameters.new("type=#{type}") unless UserNotifications.respond_to?(type)

      email_args[:email_token] = email_token if email_token.present?
      email_args[:new_email] = user.email if type.to_s == "notify_old_email"

      if args[:client_ip] && args[:user_agent]
        email_args[:client_ip] = args[:client_ip]
        email_args[:user_agent] = args[:user_agent]
      end

      if EmailLog.reached_max_emails?(user, type.to_s)
        return skip_message(SkippedEmailLog.reason_types[:exceeded_emails_limit])
      end

      if !EmailLog::CRITICAL_EMAIL_TYPES.include?(type.to_s) && user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold
        return skip_message(SkippedEmailLog.reason_types[:exceeded_bounces_limit])
      end

      if args[:user_history_id]
        email_args[:user_history] = UserHistory.where(id: args[:user_history_id]).first
      end

      message = EmailLog.unique_email_per_post(post, user) do
        UserNotifications.send(type, user, email_args)
      end

      # Update the to address if we have a custom one
      message.to = to_address if message && to_address.present?

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
      (count**4) + 15 + (rand(30) * (count + 1))
    end

    private

    def skip_message(reason)
      [nil, skip(reason)]
    end

    # If this email has a related post, don't send an email if it's been deleted or seen recently.
    def skip_email_for_post(post, user)
      if post
        if post.topic.blank?
          return SkippedEmailLog.reason_types[:user_email_topic_nil]
        end

        if post.user.blank?
          return SkippedEmailLog.reason_types[:user_email_post_user_deleted]
        end

        if post.user_deleted?
          return SkippedEmailLog.reason_types[:user_email_post_deleted]
        end

        if user.suspended? && !post.user&.staff?
          return SkippedEmailLog.reason_types[:user_email_user_suspended]
        end

        already_read = !user.user_option.email_always? && PostTiming.exists?(topic_id: post.topic_id, post_number: post.post_number, user_id: user.id)
        if already_read
          return SkippedEmailLog.reason_types[:user_email_already_read]
        end
      else
        false
      end
    end

    def skip(reason_type)
      create_skipped_email_log(
        email_type: @skip_context[:type],
        to_address: @skip_context[:to_address],
        user_id: @skip_context[:user_id],
        post_id: @skip_context[:post_id],
        reason_type: reason_type
      )
    end

  end

end
