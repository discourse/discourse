class PostAlertObserver < ActiveRecord::Observer
  observe :post_action, :post_revision

  def alerter
    @alerter ||= PostAlerter.new
  end

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

    alerter.create_notification(post.user,
                        Notification.types[:liked],
                        post,
                        display_username: post_action.user.username,
                        post_action_id: post_action.id)
  end

  def after_create_post_revision(post_revision)
    post = post_revision.post

    return unless post
    return if post_revision.user.blank?
    return if post_revision.user_id == post.user_id
    return if post.topic.private_message?

    alerter.create_notification(post.user, Notification.types[:edited], post, display_username: post_revision.user.username)
  end

  def after_create_post(post)
    if post.topic.private_message?
      # If it's a private message, notify the topic_allowed_users
      post.topic.all_allowed_users.reject{ |user| user.id == post.user_id }.each do |user|
        next if user.blank?

        if TopicUser.get(post.topic, user).try(:notification_level) == TopicUser.notification_levels[:tracking]
          next unless post.reply_to_post_number
          next unless post.reply_to_post.user_id == user.id
        end

        alerter.create_notification(user, Notification.types[:private_message], post)
      end
    elsif post.post_type != Post.types[:moderator_action]
      # If it's not a private message and it's not an automatic post caused by a moderator action, notify the users
      alerter.notify_post_users(post)
    end
  end

  protected

    def callback_for(action, model)
      "#{action}_#{model.class.name.underscore.gsub(/.+\//, '')}"
    end

end
