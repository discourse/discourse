class PostAlertObserver < ActiveRecord::Observer
  observe :post_action, :post_revision

  def self.alerter
    @alerter ||= PostAlerter.new
  end

  def alerter
    self.class.alerter
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

  def refresh_like_notification(post, read)
    return unless post && post.user_id

    usernames = post.post_actions.where(post_action_type_id: PostActionType.types[:like])
      .joins(:user)
      .order('post_actions.created_at desc')
      .where('post_actions.created_at > ?', 1.day.ago)
      .pluck(:username)

    if usernames.length > 0
      data = {
        topic_title: post.topic.title,
        username: usernames[0],
        display_username: usernames[0],
        username2: usernames[1],
        count: usernames.length
      }
      Notification.create(
        notification_type: Notification.types[:liked],
        topic_id: post.topic_id,
        post_number: post.post_number,
        user_id: post.user_id,
        read: read,
        data: data.to_json
      )
    end
  end

  def after_save_post_action(post_action)
    # We only care about deleting post actions for now
    return if post_action.deleted_at.blank?

    if post_action.post_action_type_id == PostActionType.types[:like] && post_action.post

      read = true

      Notification.where(
        topic_id: post_action.post.topic_id,
        user_id: post_action.post.user_id,
        post_number: post_action.post.post_number,
        notification_type: Notification.types[:liked]
      ).each do |notification|
        read = false unless notification.read
        notification.destroy
      end

      refresh_like_notification(post_action.post, read)
    else
      # not using destroy_all cause we want stuff to trigger
      Notification.where(post_action_id: post_action.id).each(&:destroy)
    end
  end

  def self.after_create_post_action(post_action)
    # We only notify on likes for now
    return unless post_action.is_like?

    post = post_action.post
    return if post_action.user.blank?

    alerter.create_notification(
      post.user,
      Notification.types[:liked],
      post,
      display_username: post_action.user.username,
      post_action_id: post_action.id,
      user_id: post_action.user_id
    )
  end

  def after_create_post_action(post_action)
    self.class.after_create_post_action(post_action)
  end

  def after_create_post_revision(post_revision)
    post = post_revision.post

    return unless post
    return if post_revision.user.blank?
    return if post_revision.user_id == post.user_id
    return if post.topic.private_message?
    return if SiteSetting.disable_edit_notifications && post_revision.user_id == Discourse::SYSTEM_USER_ID

    alerter.create_notification(
      post.user,
      Notification.types[:edited],
      post,
      display_username: post_revision.user.username,
      acting_user_id: post_revision.try(:user_id)
    )
  end

  protected

    def callback_for(action, model)
      "#{action}_#{model.class.name.underscore.gsub(/.+\//, '')}"
    end

end
