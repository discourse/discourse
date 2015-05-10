require_dependency 'email/sender'

module Jobs

  # Asynchronously send an email to a user
  class UserEmail < Jobs::Base

    def execute(args)

      @args = args

      # Required parameters
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      raise Discourse::InvalidParameters.new(:type) unless args[:type].present?

      # Find the user
      @user = User.find_by(id: args[:user_id])
      return skip(I18n.t("email_log.no_user", user_id: args[:user_id])) unless @user
      return skip(I18n.t("email_log.anonymous_user")) if @user.anonymous?
      return skip(I18n.t("email_log.suspended_not_pm")) if @user.suspended? && args[:type] != :user_private_message

      seen_recently = (@user.last_seen_at.present? && @user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago)
      seen_recently = false if @user.email_always

      email_args = {}

      if args[:post_id]
        # Don't email a user about a post when we've seen them recently.
        return skip(I18n.t('email_log.seen_recently')) if seen_recently

        post = Post.find_by(id: args[:post_id])
        return skip(I18n.t('email_log.post_not_found', post_id: args[:post_id])) unless post.present?

        email_args[:post] = post
      end

      email_args[:email_token] = args[:email_token] if args[:email_token].present?

      notification = nil
      notification = Notification.find_by(id: args[:notification_id]) if args[:notification_id].present?
      if notification.present?
        # Don't email a user about a post when we've seen them recently.
        return skip(I18n.t('email_log.seen_recently')) if seen_recently && !@user.suspended?

        # Load the post if present
        email_args[:post] ||= Post.find_by(id: notification.data_hash[:original_post_id].to_i)
        email_args[:post] ||= notification.post
        email_args[:notification] = notification

        return skip(I18n.t('email_log.notification_already_read')) if notification.read? && !@user.email_always
      end

      skip_reason = skip_email_for_post(email_args[:post], @user)
      return skip(skip_reason) if skip_reason

      # Make sure that mailer exists
      raise Discourse::InvalidParameters.new(:type) unless UserNotifications.respond_to?(args[:type])

      message = UserNotifications.send(args[:type], @user, email_args)
      # Update the to address if we have a custom one
      if args[:to_address].present?
        message.to = [args[:to_address]]
      end

      Email::Sender.new(message, args[:type], @user).send
    end

    private

    # If this email has a related post, don't send an email if it's been deleted or seen recently.
    def skip_email_for_post(post, user)
      if post
        return I18n.t('email_log.topic_nil') if post.topic.blank?
        return I18n.t('email_log.post_deleted') if post.user_deleted?
        return I18n.t('email_log.user_suspended') if (user.suspended? && !post.user.try(:staff?))
        return I18n.t('email_log.already_read') if PostTiming.where(topic_id: post.topic_id, post_number: post.post_number, user_id: user.id).present?
      else
        false
      end
    end

    def skip(reason)
      EmailLog.create( email_type: @args[:type],
                       to_address: @args[:to_address] || @user.try(:email) || "no_email_found",
                       user_id: @user.try(:id),
                       skipped: true,
                       skipped_reason: reason)
    end

  end

end
