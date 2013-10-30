require_dependency 'email/sender'

module Jobs

  # Asynchronously send an email to a user
  class UserEmail < Jobs::Base

    def execute(args)

      # Required parameters
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      raise Discourse::InvalidParameters.new(:type) unless args[:type].present?

      # Find the user
      user = User.where(id: args[:user_id]).first
      return unless user
      return if user.is_banned? && args[:type] != :user_private_message

      seen_recently = (user.last_seen_at.present? && user.last_seen_at > SiteSetting.email_time_window_mins.minutes.ago)
      seen_recently = false if user.email_always

      email_args = {}

      if args[:post_id]

        # Don't email a user about a post when we've seen them recently.
        return if seen_recently

        post = Post.where(id: args[:post_id]).first
        return unless post.present?

        email_args[:post] = post
      end

      email_args[:email_token] = args[:email_token] if args[:email_token].present?

      notification = nil
      notification = Notification.where(id: args[:notification_id]).first if args[:notification_id].present?
      if notification.present?
        # Don't email a user about a post when we've seen them recently.
        return if seen_recently && !user.is_banned?

        # Load the post if present
        email_args[:post] ||= notification.post
        email_args[:notification] = notification

        # Don't send email if the notification this email is about has already been read
        return if notification.read?
      end

      return if skip_email_for_post(email_args[:post], user)

      # Make sure that mailer exists
      raise Discourse::InvalidParameters.new(:type) unless UserNotifications.respond_to?(args[:type])

      message = UserNotifications.send(args[:type], user, email_args)
      # Update the to address if we have a custom one
      if args[:to_address].present?
        message.to = [args[:to_address]]
      end

      Email::Sender.new(message, args[:type], user).send
    end

    private

    # If this email has a related post, don't send an email if it's been deleted or seen recently.
    def skip_email_for_post(post, user)
      post &&
      (post.topic.blank? ||
       post.user_deleted? ||
       (user.is_banned? && !post.user.try(:staff?)) ||
       PostTiming.where(topic_id: post.topic_id, post_number: post.post_number, user_id: user.id).present?)
    end

  end

end
