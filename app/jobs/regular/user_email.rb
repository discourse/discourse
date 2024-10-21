# frozen_string_literal: true

module Jobs
  # Asynchronously send an email to a user
  class UserEmail < ::Jobs::Base
    include Skippable

    sidekiq_options queue: "low"

    sidekiq_retry_in do |count, exception|
      # retry in an hour when SMTP server is busy
      # or use default sidekiq retry formula. returning
      # nil/0 will trigger the default sidekiq
      # retry formula
      #
      # See https://github.com/mperham/sidekiq/blob/3330df0ee37cfd3e0cd3ef01e3e66b584b99d488/lib/sidekiq/job_retry.rb#L216-L234
      case exception.wrapped
      when Net::SMTPServerBusy
        return 1.hour + (rand(30) * (count + 1))
      end
    end

    # Can be overridden by subclass, for example critical email
    # should always consider being sent
    def quit_email_early?
      SiteSetting.disable_emails == "yes"
    end

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) if args[:user_id].blank?
      raise Discourse::InvalidParameters.new(:type) if args[:type].blank?

      # This is for performance. Quit out fast without doing a bunch
      # of extra work when emails are disabled.
      return if quit_email_early?

      args[:type] = args[:type].to_s

      send_user_email(args)

      if args[:type] == "digest"
        # Record every attempt at sending a digest email, even if it was skipped
        UserStat.where(user_id: args[:user_id]).update_all(digest_attempted_at: Time.current)
      end
    end

    def send_user_email(args)
      post = nil
      notification = nil
      type = args[:type]
      user = User.find_by(id: args[:user_id])
      to_address =
        args[:to_address].presence || user&.primary_email&.email.presence || "no_email_found"

      set_skip_context(type, args[:user_id], to_address, args[:post_id])

      return skip(SkippedEmailLog.reason_types[:user_email_no_user]) if !user
      if to_address == "no_email_found"
        return skip(SkippedEmailLog.reason_types[:user_email_no_email])
      end

      if args[:post_id].present?
        post = Post.find_by(id: args[:post_id])

        return skip(SkippedEmailLog.reason_types[:user_email_post_not_found]) if post.blank?

        if !Guardian.new(user).can_see?(post)
          return skip(SkippedEmailLog.reason_types[:user_email_access_denied])
        end
      end

      if args[:notification_id].present?
        notification = Notification.find_by(id: args[:notification_id])
      end

      message, skip_reason_type = message_for_email(user, post, type, notification, args)

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

    NOTIFICATIONS_SENT_BY_MAILING_LIST = Set.new %w[posted replied mentioned group_mentioned quoted]

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

      if user.suspended?
        if !type.in?(%w[user_private_message account_suspended])
          return skip_message(SkippedEmailLog.reason_types[:user_email_user_suspended_not_pm])
        elsif post&.topic&.group_pm?
          return skip_message(SkippedEmailLog.reason_types[:user_email_user_suspended])
        end
      end

      if type == "digest"
        # same checks as in the "enqueue_digest_emails" job
        # in case something changed since the job was enqueued
        return if SiteSetting.disable_digest_emails? || SiteSetting.private_email?

        return if user.bot? || user.anonymous? || !user.active || user.suspended? || user.staged

        return if !user.user_stat
        return if user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold

        return if !user.user_option
        return if !user.user_option.email_digests
        return if user.user_option.mailing_list_mode

        delay = user.user_option.digest_after_minutes || SiteSetting.default_email_digest_frequency
        delay = delay.to_i

        return if delay <= 0 # 0 means never send digest

        if user.user_stat.digest_attempted_at
          return if user.user_stat.digest_attempted_at > delay.minutes.ago
        end

        if user.last_seen_at
          return if user.last_seen_at > delay.minutes.ago
        end
      end

      seen_recently =
        user.last_seen_at && user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago

      if !args[:force_respect_seen_recently] &&
           (
             always_email_regular?(user, type) || always_email_private_message?(user, type) ||
               user.staged
           )
        seen_recently = false
      end

      email_args = {}

      if (post || notification || notification_type || args[:force_respect_seen_recently]) &&
           (seen_recently && !user.suspended?)
        return skip_message(SkippedEmailLog.reason_types[:user_email_seen_recently])
      end

      email_args[:post] = post if post

      if notification || notification_type
        email_args[:notification_type] ||= notification_type || notification.try(:notification_type)
        email_args[:notification_data_hash] ||= notification_data_hash ||
          notification.try(:data_hash)

        unless String === email_args[:notification_type]
          if Numeric === email_args[:notification_type]
            email_args[:notification_type] = Notification.types[email_args[:notification_type]]
          end
          email_args[:notification_type] = email_args[:notification_type].to_s
        end

        # don't catch notifications for users on daily mailing list mode
        if user.user_option.mailing_list_mode && user.user_option.mailing_list_mode_frequency > 0
          if !post&.topic&.private_message? &&
               NOTIFICATIONS_SENT_BY_MAILING_LIST.include?(email_args[:notification_type])
            # no need to log a reason when the mail was already sent via the mailing list job
            return
          end
        end

        unless always_email_regular?(user, type) || always_email_private_message?(user, type)
          if notification&.read? || post&.seen?(user)
            return skip_message(SkippedEmailLog.reason_types[:user_email_notification_already_read])
          end
        end
      end

      skip_reason_type = skip_email_for_post(post, user)
      return skip_message(skip_reason_type) if skip_reason_type.present?

      # Make sure that mailer exists
      unless UserNotifications.respond_to?(type)
        raise Discourse::InvalidParameters.new("type=#{type}")
      end

      if email_token.present?
        email_args[:email_token] = email_token

        if type == "confirm_new_email"
          change_req = EmailChangeRequest.find_by_new_token(email_token)

          email_args[:requested_by_admin] = change_req.requested_by_admin? if change_req
        end
      end

      email_args[:new_email] = args[:new_email] || user.email if type == "notify_old_email" ||
        type == "notify_old_email_add"

      if args[:client_ip] && args[:user_agent]
        email_args[:client_ip] = args[:client_ip]
        email_args[:user_agent] = args[:user_agent]
      end

      if EmailLog.reached_max_emails?(user, type)
        return skip_message(SkippedEmailLog.reason_types[:exceeded_emails_limit])
      end

      if !EmailLog::CRITICAL_EMAIL_TYPES.include?(type) &&
           user.user_stat.bounce_score >= SiteSetting.bounce_score_threshold
        return skip_message(SkippedEmailLog.reason_types[:exceeded_bounces_limit])
      end

      if args[:user_history_id]
        email_args[:user_history] = UserHistory.where(id: args[:user_history_id]).first
      end

      email_args[:reject_reason] = args[:reject_reason]

      message =
        EmailLog.unique_email_per_post(post, user) do
          UserNotifications.public_send(type, user, email_args)
        end

      # Update the to address if we have a custom one
      message.to = to_address if message && to_address.present?

      [message, nil]
    end

    private

    def skip_message(reason)
      [nil, skip(reason)]
    end

    # If this email has a related post, don't send an email if it's been deleted or seen recently.
    def skip_email_for_post(post, user)
      return false unless post

      return SkippedEmailLog.reason_types[:user_email_topic_nil] if post.topic.blank?

      return SkippedEmailLog.reason_types[:user_email_post_user_deleted] if post.user.blank?

      return SkippedEmailLog.reason_types[:user_email_post_deleted] if post.user_deleted?

      if user.suspended? && (!post.user&.staff? || !post.user&.human?)
        return SkippedEmailLog.reason_types[:user_email_user_suspended]
      end

      already_read =
        user.user_option.email_level != UserOption.email_level_types[:always] &&
          PostTiming.exists?(
            topic_id: post.topic_id,
            post_number: post.post_number,
            user_id: user.id,
          )
      SkippedEmailLog.reason_types[:user_email_already_read] if already_read
    end

    def skip(reason_type)
      create_skipped_email_log(
        email_type: @skip_context[:type],
        to_address: @skip_context[:to_address],
        user_id: @skip_context[:user_id],
        post_id: @skip_context[:post_id],
        reason_type: reason_type,
      )
    end

    def always_email_private_message?(user, type)
      type == "user_private_message" &&
        user.user_option.email_messages_level == UserOption.email_level_types[:always]
    end

    def always_email_regular?(user, type)
      type != "user_private_message" &&
        user.user_option.email_level == UserOption.email_level_types[:always]
    end
  end
end
