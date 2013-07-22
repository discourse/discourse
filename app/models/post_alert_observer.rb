class PostAlertObserver < ActiveRecord::Observer
  observe :post, VestalVersions::Version, :post_action

  # Dispatch to an after_save_#{class_name} method
  def after_save(model)
    method_name = callback_for('after_save', model)
    send(method_name, model) if respond_to?(method_name)
  end

  # Dispatch to an after_create_#{class_name} method
  def after_create(model)
    method_name = callback_for('after_create', model)
    send(method_name, model) if respond_to?(method_name)
  end

  # We need to consider new people to mention / quote when a post is edited
  def after_save_post(post)
    return if post.topic.private_message?

    mentioned_users = extract_mentioned_users(post)
    quoted_users = extract_quoted_users(post)

    reply_to_user = post.reply_notification_target
    notify_users(mentioned_users - [reply_to_user], :mentioned, post)
    notify_users(quoted_users - mentioned_users - [reply_to_user], :quoted, post)
  end

  def after_save_post_action(post_action)
    # We only care about deleting post actions for now
    return if post_action.deleted_at.blank?
    Notification.where(post_action_id: post_action.id).each(&:destroy)
  end

  def after_create_post_action(post_action)
    # We only notify on likes for now
    return unless post_action.is_like?

    post = post_action.post
    return if post_action.user.blank?
    return if post.topic.private_message?

    create_notification(post.user,
                        Notification.types[:liked],
                        post,
                        display_username: post_action.user.username,
                        post_action_id: post_action.id)
  end

  def after_create_version(version)
    post = version.versioned

    return unless post.is_a?(Post)
    return if version.user.blank?
    return if version.user_id == post.user_id
    return if post.topic.private_message?

    create_notification(post.user, Notification.types[:edited], post, display_username: version.user.username)
  end

  def after_create_post(post)
    if post.topic.private_message?
      # If it's a private message, notify the topic_allowed_users
      post.topic.all_allowed_users.reject{ |a| a.id == post.user_id }.each do |a|
        create_notification(a, Notification.types[:private_message], post)
      end
    elsif post.post_type != Post.types[:moderator_action]
      # If it's not a private message and it's not an automatic post caused by a moderator action, notify the users
      notify_post_users(post)
    end
  end

  protected

    def callback_for(action, model)
      "#{action}_#{model.class.name.underscore.gsub(/.+\//, '')}"
    end

    def create_notification(user, type, post, opts={})
      return if user.blank?

      # Make sure the user can see the post
      return unless Guardian.new(user).can_see?(post)

      # skip if muted on the topic
      return if TopicUser.get(post.topic, user).try(:notification_level) == TopicUser.notification_levels[:muted]

      # Don't notify the same user about the same notification on the same post
      return if user.notifications.exists?(notification_type: type, topic_id: post.topic_id, post_number: post.post_number)

      # Create the notification
      user.notifications.create(notification_type: type,
                                topic_id: post.topic_id,
                                post_number: post.post_number,
                                post_action_id: opts[:post_action_id],
                                data: { topic_title: post.topic.title,
                                        display_username: opts[:display_username] || post.user.username }.to_json)
    end

    # TODO: Move to post-analyzer?
    # Returns a list users who have been mentioned
    def extract_mentioned_users(post)
      User.where(username_lower: post.raw_mentions).where("id <> ?", post.user_id)
    end

    # TODO: Move to post-analyzer?
    # Returns a list of users who were quoted in the post
    def extract_quoted_users(post)
      post.raw.scan(/\[quote=\"([^,]+),.+\"\]/).uniq.map do |m|
        User.where("username_lower = :username and id != :id", username: m.first.strip.downcase, id: post.user_id).first
      end.compact
    end

    # Notify a bunch of users
    def notify_users(users, type, post)
      users = [users] unless users.is_a?(Array)
      users.each do |u|
        create_notification(u, Notification.types[type], post)
      end
    end

    # TODO: This should use javascript for parsing rather than re-doing it this way.
    def notify_post_users(post)
      # Is this post a reply to a user?
      reply_to_user = post.reply_notification_target
      notify_users(reply_to_user, :replied, post)

      # find all users watching
      if post.post_number > 1
        exclude_user_ids = []
        exclude_user_ids << post.user_id
        exclude_user_ids << reply_to_user.id if reply_to_user.present?
        exclude_user_ids << extract_mentioned_users(post).map(&:id)
        exclude_user_ids << extract_quoted_users(post).map(&:id)
        exclude_user_ids.flatten!
        TopicUser.where(topic_id: post.topic_id, notification_level: TopicUser.notification_levels[:watching]).includes(:user).each do |tu|
          create_notification(tu.user, Notification.types[:posted], post) unless exclude_user_ids.include?(tu.user_id)
        end
      end
    end
end
