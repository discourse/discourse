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
      return if user.suspended? && args[:type] != :user_private_message

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
        return if seen_recently && !user.suspended?

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

    def notification_email(user, opts)
      return unless @notification = opts[:notification]
      return unless @post = opts[:post]

      username = @notification.data_hash[:display_username]
      notification_type = opts[:notification_type] || Notification.types[@notification.notification_type].to_s

      context = ""
      tu = TopicUser.get(@post.topic_id, user)

      context_posts = Post.where(topic_id: @post.topic_id)
                          .where("post_number < ?", @post.post_number)
                          .where(user_deleted: false)
                          .order('created_at desc')
                          .limit(SiteSetting.email_posts_context)

      if tu && tu.last_emailed_post_number
        context_posts = context_posts.where("post_number > ?", tu.last_emailed_post_number)
      end

      # make .present? cheaper
      context_posts = context_posts.to_a

      if context_posts.present?
        context << "---\n*#{I18n.t('user_notifications.previous_discussion')}*\n"
        context_posts.each do |cp|
          context << email_post_markdown(cp)
        end
      end

      html = UserNotificationRenderer.new(Rails.configuration.paths["app/views"]).render(
        template: 'email/notification',
        format: :html,
        locals: { context_posts: context_posts, post: @post }
      )

      if @post.topic.private_message?
        opts[:subject_prefix] = "[#{I18n.t('private_message_abbrev')}] "
      end

      email_opts = {
        topic_title: @notification.data_hash[:topic_title],
        message: email_post_markdown(@post),
        url: @post.url,
        post_id: @post.id,
        topic_id: @post.topic_id,
        context: context,
        username: username,
        add_unsubscribe_link: true,
        allow_reply_by_email: opts[:allow_reply_by_email],
        template: "user_notifications.user_#{notification_type}",
        html_override: html,
        style: :notification,
        subject_prefix: opts[:subject_prefix] || ''
      }

      # If we have a display name, change the from address
      if username.present?
        email_opts[:from_alias] = username
      end

      TopicUser.change(user.id, @post.topic_id, last_emailed_post_number: @post.post_number)

      build_email(user.email, email_opts)
    end

    private

    # If this email has a related post, don't send an email if it's been deleted or seen recently.
    def skip_email_for_post(post, user)
      post &&
      (post.topic.blank? ||
       post.user_deleted? ||
       (user.suspended? && !post.user.try(:staff?)) ||
       PostTiming.where(topic_id: post.topic_id, post_number: post.post_number, user_id: user.id).present?)
    end

  end

end
