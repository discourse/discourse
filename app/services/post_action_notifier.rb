class PostActionNotifier

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.alerter
    @alerter ||= PostAlerter.new
  end

  def self.refresh_like_notification(post, read)
    return unless post && post.user_id && post.topic

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

  def self.post_action_deleted(post_action)
    return if @disabled

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

  def self.post_action_created(post_action)
    return if @disabled

    # We only notify on likes for now
    return unless post_action.is_like?

    post = post_action.post
    return if post_action.user.blank?

    user_notifications = post.user.notifications

    consolidation_window =
      SiteSetting.likes_notification_consolidation_window_mins.minutes.ago

    liked_by_user_notifications =
      user_notifications
        .get_liked_by(post_action.user)
        .where("created_at > ?", consolidation_window)

    user_liked_consolidated_notification =
      user_notifications
        .where(
          "created_at > ? AND notification_type = ?",
          consolidation_window,
          Notification.types[:liked_consolidated]
        )
        .first

    if user_liked_consolidated_notification
      update_consolidated_liked_notification_count!(
        user_liked_consolidated_notification
      )
    elsif (
      liked_by_user_notifications.count >=
      SiteSetting.likes_notification_consolidation_threshold
    )
      create_consolidated_liked_notification!(
        liked_by_user_notifications,
        post,
        post_action
      )
    else
      alerter.create_notification(
        post.user,
        Notification.types[:liked],
        post,
        display_username: post_action.user.username,
        post_action_id: post_action.id,
        user_id: post_action.user_id
      )
    end
  end

  def self.update_consolidated_liked_notification_count!(notification)
    Notification.transaction do
      data = JSON.parse(notification.data)
      data["count"] += 1

      notification.update!(
        data: data.to_json,
        read: false
      )
    end
  end
  private_class_method :update_consolidated_liked_notification_count!

  def self.create_consolidated_liked_notification!(notifications,
                                                  post,
                                                  post_action)

    Notification.transaction do
      timestamp = notifications.last.created_at

      Notification.create!(
        notification_type: Notification.types[:liked_consolidated],
        user_id: post.user_id,
        data: {
          username: post_action.user.username,
          display_username: post_action.user.username,
          count: notifications.count + 1
        }.to_json,
        updated_at: timestamp,
        created_at: timestamp
      )

      notifications.delete_all
    end
  end
  private_class_method :create_consolidated_liked_notification!

  def self.after_create_post_revision(post_revision)
    return if @disabled

    post = post_revision.post

    return unless post
    return if post_revision.user.blank?
    return if post_revision.user_id == post.user_id
    return if post.topic.blank?
    return if post.topic.private_message?
    return if SiteSetting.disable_edit_notifications && post_revision.user_id == Discourse::SYSTEM_USER_ID

    alerter.create_notification(
      post.user,
      Notification.types[:edited],
      post,
      display_username: post_revision.user.username,
      acting_user_id: post_revision.try(:user_id),
      revision_number: post_revision.number
    )
  end

  def self.after_post_unhide(post, flaggers)
    return if @disabled || post.last_editor.blank? || flaggers.blank?

    flaggers.each do |flagger|
      alerter.create_notification(
        flagger,
        Notification.types[:edited],
        post,
        display_username: post.last_editor.username,
        acting_user_id: post.last_editor.id
      )
    end
  end
end
