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

    class MailSender
      include Skippable

      NOTIFICATIONS_SENT_BY_MAILING_LIST ||=
        Set.new %w[posted replied mentioned group_mentioned quoted]

      attr_reader :args,
                  :type,
                  :user,
                  :to_address,
                  :guardian,
                  :notification_type,
                  :notification_data_hash,
                  :email_token

      delegate :user_stat, to: :user, private: true
      delegate :user_option, to: :user, private: true
      delegate :bounce_score,
               :mailing_list_mode?,
               :mailing_list_mode_frequency,
               to: :user_stat,
               private: true
      delegate :mailing_list_mode?, :mailing_list_mode_frequency, to: :user_option, private: true

      def initialize(args)
        @args = args
        @notification = nil
        @type = ActiveSupport::StringInquirer.new(args[:type].to_s)
        @user = User.find_by(id: args[:user_id])
        @to_address = args[:to_address].presence || user&.primary_email&.email.presence
        @guardian = Guardian.new(user)
        @notification_type = args[:notification_type]
        @notification_data_hash = args[:notification_data_hash]
        @email_token = args[:email_token]
      end

      def call
        send_user_email
        if type.digest?
          # Record every attempt at sending a digest email, even if it was skipped
          UserStat.where(user_id: args[:user_id]).update_all(digest_attempted_at: Time.current)
        end
      end

      private

      def send_user_email
        return skip(:user_email_no_user) if !user
        return skip(:user_email_no_email) unless to_address
        if args[:post_id].present?
          return skip(:user_email_post_not_found) if post.blank?
          return skip(:user_email_access_denied) unless guardian.can_see?(post)
        end
        message, skip_reason_type = message_for_email
        return skip_reason_type unless message
        Email::Sender.new(message, type, user).send
        if bounce_score > SiteSetting.bounce_score_erode_on_send
          # erode bounce score each time we send an email
          # this means that we are punished a lot less for bounces
          # and we can recover more quickly
          user_stat.update(bounce_score: bounce_score - SiteSetting.bounce_score_erode_on_send)
        end
      end

      def post
        return @post if defined?(@post)
        return unless args[:post_id].present?
        @post = Post.find_by(id: args[:post_id])
      end

      def notification
        return @notification if defined?(@notification)
        return unless args[:notification_id].present?
        @notification = Notification.find_by(id: args[:notification_id])
      end

      def skip(reason_type)
        create_skipped_email_log(
          email_type: type,
          to_address: to_address || "email_not_found",
          user_id: args[:user_id],
          post_id: args[:post_id],
          reason_type: SkippedEmailLog.reason_types[reason_type],
        )
      end

      def skip_message(reason)
        [nil, skip(reason)]
      end

      def always_email_private_message?
        type.user_private_message? &&
          user.user_option.email_messages_level == UserOption.email_level_types[:always]
      end

      def always_email_regular?
        !type.user_private_message? &&
          user.user_option.email_level == UserOption.email_level_types[:always]
      end

      # If this email has a related post, don't send an email if it's been deleted or seen recently.
      def skip_email_for_post
        return false unless post
        return :user_email_topic_nil if post.topic.blank?
        return :user_email_post_user_deleted if post.user.blank?
        return :user_email_post_deleted if post.user_deleted?

        if user.suspended? && (!post.user&.staff? || !post.user&.human?)
          return :user_email_user_suspended
        end

        already_read =
          user.user_option.email_level != UserOption.email_level_types[:always] &&
            PostTiming.exists?(
              topic_id: post.topic_id,
              post_number: post.post_number,
              user_id: user.id,
            )
        :user_email_already_read if already_read
      end

      def notification_type
        args[:notification_type] || notification&.notification_type
      end

      def notification_data_hash
        args[:notification_data_hash] || notification&.data_hash
      end

      def message_for_email
        return skip_message(:user_email_anonymous_user) if user.anonymous?

        if user.suspended?
          if !type.user_private_message? && !type.account_suspended?
            return skip_message(:user_email_user_suspended_not_pm)
          end
          return skip_message(:user_email_user_suspended) if post.topic.group_pm?
        end

        if type.digest?
          return if user.staged?
          if user.last_emailed_at &&
               user.last_emailed_at >
                 (
                   user.user_option&.digest_after_minutes ||
                     SiteSetting.default_email_digest_frequency.to_i
                 ).minutes.ago
            return
          end
        end

        seen_recently =
          (user.last_seen_at? && user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago)
        if !args[:force_respect_seen_recently] &&
             (always_email_regular? || always_email_private_message? || user.staged?)
          seen_recently = false
        end

        email_args = {}

        if (post || notification || notification_type || args[:force_respect_seen_recently]) &&
             (seen_recently && !user.suspended?)
          return skip_message(:user_email_seen_recently)
        end

        email_args[:post] = post if post

        if notification || notification_type
          email_args[:notification_type] = notification_type
          email_args[:notification_data_hash] = notification_data_hash

          unless String === email_args[:notification_type]
            if Numeric === email_args[:notification_type]
              email_args[:notification_type] = Notification.types[email_args[:notification_type]]
            end
            email_args[:notification_type] = email_args[:notification_type].to_s
          end

          if !SiteSetting.disable_mailing_list_mode && mailing_list_mode? &&
               mailing_list_mode_frequency > 0 && (!post&.topic&.private_message?) && # don't catch notifications for users on daily mailing list mode
               NOTIFICATIONS_SENT_BY_MAILING_LIST.include?(email_args[:notification_type])
            # no need to log a reason when the mail was already sent via the mailing list job
            return nil, nil
          end

          unless always_email_regular? || always_email_private_message?
            if (notification&.read?) || (post&.seen?(user))
              return(skip_message(:user_email_notification_already_read))
            end
          end
        end

        skip_reason_type = skip_email_for_post
        return skip_message(skip_reason_type) if skip_reason_type.present?

        # Make sure that mailer exists
        unless UserNotifications.respond_to?(type)
          raise Discourse::InvalidParameters.new("type=#{type}")
        end

        if email_token.present?
          email_args[:email_token] = email_token

          if type.confirm_new_email?
            change_req = EmailChangeRequest.find_by_new_token(email_token)

            email_args[:requested_by_admin] = change_req.requested_by_admin? if change_req
          end
        end

        email_args[:new_email] = args[:new_email] || user.email if type.notify_old_email? ||
          type.notify_old_email_add?

        if args[:client_ip] && args[:user_agent]
          email_args[:client_ip] = args[:client_ip]
          email_args[:user_agent] = args[:user_agent]
        end

        return skip_message(:exceeded_emails_limit) if EmailLog.reached_max_emails?(user, type)

        if !EmailLog::CRITICAL_EMAIL_TYPES.include?(type) &&
             bounce_score >= SiteSetting.bounce_score_threshold
          return skip_message(:exceeded_bounces_limit)
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
    end

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      raise Discourse::InvalidParameters.new(:type) unless args[:type].present?

      # This is for performance. Quit out fast without doing a bunch
      # of extra work when emails are disabled.
      return if quit_email_early?
      MailSender.new(args).call
    end
  end
end
