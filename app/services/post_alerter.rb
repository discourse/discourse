class PostAlerter

  def self.post_created(post)
    alerter = PostAlerter.new
    alerter.after_save_post(post, true)
    post
  end

  def not_allowed?(user, post)
    user.blank? ||
    user.id == Discourse::SYSTEM_USER_ID ||
    user.id == post.user_id
  end

  def all_allowed_users(post)
    @all_allowed_users ||= post.topic.all_allowed_users.reject { |u| not_allowed?(u, post) }
  end

  def allowed_users(post)
    @allowed_users ||= post.topic.allowed_users.reject { |u| not_allowed?(u, post) }
  end

  def allowed_group_users(post)
    @allowed_group_users ||= post.topic.allowed_group_users.reject { |u| not_allowed?(u, post) }
  end

  def directly_targeted_users(post)
    allowed_users(post) - allowed_group_users(post)
  end

  def indirectly_targeted_users(post)
    allowed_group_users(post)
  end

  def after_save_post(post, new_record = false)
    notified = [post.user]

    # mentions (users/groups)
    mentioned_groups, mentioned_users = extract_mentions(post)

    if mentioned_groups || mentioned_users
      mentioned_opts = {}
      if post.last_editor_id != post.user_id
        # Mention comes from an edit by someone else, so notification should say who added the mention.
        editor = post.last_editor
        mentioned_opts = {user_id: editor.id, original_username: editor.username, display_username: editor.username}
      end

      expand_group_mentions(mentioned_groups, post) do |group, users|
        notify_non_pm_users(users - notified, :group_mentioned, post, mentioned_opts.merge({group: group}))
        notified += users
      end

      if mentioned_users
        notify_non_pm_users(mentioned_users - notified, :mentioned, post, mentioned_opts)
        notified += mentioned_users
      end
    end

    # replies
    reply_to_user = post.reply_notification_target

    if new_record && reply_to_user && !notified.include?(reply_to_user) && post.post_type == Post.types[:regular]
      notify_non_pm_users(reply_to_user, :replied, post)
      notified += [reply_to_user]
    end

    # quotes
    quoted_users = extract_quoted_users(post)
    notify_non_pm_users(quoted_users - notified, :quoted, post)
    notified += quoted_users

    # linked
    linked_users = extract_linked_users(post)
    notify_non_pm_users(linked_users - notified, :linked, post)
    notified += linked_users

    # private messages
    if new_record
      if post.topic.private_message?
        # users that aren't part of any mentioned groups
        directly_targeted_users(post).each do |user|
          notification_level = TopicUser.get(post.topic, user).try(:notification_level)
          if notified.include?(user) || notification_level == TopicUser.notification_levels[:watching]
            create_notification(user, Notification.types[:private_message], post)
          end
        end
        # users that are part of all mentionned groups
        indirectly_targeted_users(post).each do |user|
          # only create a notification when watching the group
          notification_level = TopicUser.get(post.topic, user).try(:notification_level)

          if notification_level == TopicUser.notification_levels[:watching]
            create_notification(user, Notification.types[:private_message], post)
          elsif notification_level == TopicUser.notification_levels[:tracking]
            if notified.include?(user)
              create_notification(user, Notification.types[:private_message], post)
            else
              notify_group_summary(user, post)
            end
          end
        end
      elsif post.post_type == Post.types[:regular]
        # If it's not a private message and it's not an automatic post caused by a moderator action, notify the users
        notify_post_users(post, notified)
      end
    end

    sync_group_mentions(post, mentioned_groups)
  end

  def sync_group_mentions(post, mentioned_groups)
    GroupMention.where(post_id: post.id).destroy_all
    return if mentioned_groups.blank?

    mentioned_groups.each do |group|
      GroupMention.create(post_id: post.id, group_id: group.id)
    end
  end

  def unread_posts(user, topic)
    Post.secured(Guardian.new(user))
        .where('post_number > COALESCE((
               SELECT last_read_post_number FROM topic_users tu
               WHERE tu.user_id = ? AND tu.topic_id = ? ),0)',
                user.id, topic.id)
        .where('reply_to_user_id = ? OR exists(
            SELECT 1 from topic_users tu
            WHERE tu.user_id = ? AND
              tu.topic_id = ? AND
              notification_level = ?
            )', user.id, user.id, topic.id, TopicUser.notification_levels[:watching])
        .where(topic_id: topic.id)
  end

  def first_unread_post(user, topic)
    unread_posts(user, topic).order('post_number').first
  end

  def unread_count(user, topic)
    unread_posts(user, topic).count
  end

  def destroy_notifications(user, type, topic)
    return if user.blank?
    return unless Guardian.new(user).can_see?(topic)

    user.notifications.where(notification_type: type,
                             topic_id: topic.id).destroy_all
    # HACK so notification counts sync up correctly
    user.reload
  end

  NOTIFIABLE_TYPES = [:mentioned, :replied, :quoted, :posted, :linked, :private_message, :group_mentioned].map{ |t|
    Notification.types[t]
  }

  def group_stats(topic)
    topic.allowed_groups.map do |g|
      {
        group_id: g.id,
        group_name: g.name.downcase,
        inbox_count: Topic.exec_sql(
        "SELECT COUNT(*) FROM topics t
         JOIN topic_allowed_groups g ON g.group_id = :group_id AND g.topic_id = t.id
         LEFT JOIN group_archived_messages a ON a.topic_id = t.id AND a.group_id = g.group_id
         WHERE a.id IS NULL AND t.deleted_at is NULL AND t.archetype = 'private_message'",
          group_id: g.id).values[0][0].to_i
      }
    end
  end

  def notify_group_summary(user,post)

    @group_stats ||= {}
    stats = (@group_stats[post.topic_id] ||= group_stats(post.topic))
    return unless stats

    group_id = post.topic
                   .topic_allowed_groups
                   .where(group_id: user.groups.pluck(:id))
                   .pluck(:group_id).first

    stat = stats.find{|s| s[:group_id] == group_id}
    return unless stat && stat[:inbox_count] > 0

    notification_type = Notification.types[:group_message_summary]

    Notification.where(notification_type: notification_type, user_id: user.id).each do |n|
      n.destroy if n.data_hash[:group_id] == stat[:group_id]
    end

    Notification.create(
      notification_type: notification_type,
      user_id: user.id,
      data: {
        group_id: stat[:group_id],
        group_name: stat[:group_name],
        inbox_count: stat[:inbox_count],
        username: user.username_lower
      }.to_json
    )

    # TODO decide if it makes sense to also publish a desktop notification
  end

  def should_notify_edit?(notification, opts)
    return notification.data_hash["display_username"] != opts[:display_username]
  end

  def should_notify_like?(user, notification)

    return true if user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:always]

    return true if user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:first_time_and_daily] && notification.created_at < 1.day.ago

    return false
  end

  def should_notify_previous?(user, notification, opts)
    case notification.notification_type
    when Notification.types[:edited] then should_notify_edit?(notification, opts)
    when Notification.types[:liked]  then should_notify_like?(user, notification)
    else false
    end
  end

  COLLAPSED_NOTIFICATION_TYPES ||= [
    Notification.types[:replied],
    Notification.types[:quoted],
    Notification.types[:posted],
  ]

  def create_notification(user, type, post, opts=nil)
    return if user.blank?
    return if user.id == Discourse::SYSTEM_USER_ID

    return if type == Notification.types[:liked] && user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:never]

    opts ||= {}

    # Make sure the user can see the post
    return unless Guardian.new(user).can_see?(post)

    notifier_id = opts[:user_id] || post.user_id # xxxxx look at revision history

    # apply muting here
    return if notifier_id && MutedUser.where(user_id: user.id, muted_user_id: notifier_id)
                                      .joins(:muted_user)
                                      .where('NOT admin AND NOT moderator')
                                      .exists?

    # skip if muted on the topic
    return if TopicUser.get(post.topic, user).try(:notification_level) == TopicUser.notification_levels[:muted]

    # skip if muted on the group
    if group = opts[:group]
      return if GroupUser.find_by(group_id: opts[:group_id], user_id: user.id).try(:notification_level) == TopicUser.notification_levels[:muted]
    end

    # Don't notify the same user about the same notification on the same post
    existing_notification = user.notifications
                                .order("notifications.id DESC")
                                .find_by(topic_id: post.topic_id,
                                         post_number: post.post_number,
                                         notification_type: type)

    return if existing_notification && !should_notify_previous?(user, existing_notification, opts)

    notification_data = {}

    if  existing_notification &&
        existing_notification.created_at > 1.day.ago &&
        user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:always]

      data = existing_notification.data_hash
      notification_data["username2"] = data["display_username"]
      notification_data["count"] = (data["count"] || 1).to_i + 1
      # don't use destroy so we don't trigger a notification count refresh
      Notification.where(id: existing_notification.id).destroy_all
    end

    collapsed = false

    if COLLAPSED_NOTIFICATION_TYPES.include?(type)
      COLLAPSED_NOTIFICATION_TYPES.each do |t|
        destroy_notifications(user, t, post.topic)
      end
      collapsed = true
    end

    if type == Notification.types[:private_message]
      destroy_notifications(user, type, post.topic)
      collapsed = true
    end

    original_post = post
    original_username = opts[:display_username] || post.username # xxxxx need something here too

    if collapsed
      post = first_unread_post(user, post.topic) || post
      count = unread_count(user, post.topic)
      if count > 1
        I18n.with_locale(user.effective_locale) do
          opts[:display_username] = I18n.t('embed.replies', count: count)
        end
      end
    end

    UserActionObserver.log_notification(original_post, user, type, opts[:acting_user_id])

    topic_title = post.topic.title
    # when sending a private message email, keep the original title
    if post.topic.private_message? && modifications = post.revisions.map(&:modifications)
      if first_title_modification = modifications.find { |m| m.has_key?("title") }
        topic_title = first_title_modification["title"][0]
      end
    end

    notification_data.merge!({
      topic_title: topic_title,
      original_post_id: original_post.id,
      original_post_type: original_post.post_type,
      original_username: original_username,
      display_username: opts[:display_username] || post.user.username
    })

    if group = opts[:group]
      notification_data[:group_id] = group.id
      notification_data[:group_name] = group.name
    end

    # Create the notification
    user.notifications.create(notification_type: type,
                              topic_id: post.topic_id,
                              post_number: post.post_number,
                              post_action_id: opts[:post_action_id],
                              data: notification_data.to_json)

   if !existing_notification && NOTIFIABLE_TYPES.include?(type)
     # we may have an invalid post somehow, dont blow up
     post_url = original_post.url rescue nil
     if post_url
        MessageBus.publish("/notification-alert/#{user.id}", {
          notification_type: type,
          post_number: original_post.post_number,
          topic_title: original_post.topic.title,
          topic_id: original_post.topic.id,
          excerpt: original_post.excerpt(400, text_entities: true, strip_links: true),
          username: original_username,
          post_url: post_url
        }, user_ids: [user.id])
     end
   end

  end

  def expand_group_mentions(groups, post)
    return unless post.user && groups

    Group.mentionable(post.user).where(id: groups.map(&:id)).each do |group|
      next if group.user_count >= SiteSetting.max_users_notified_per_group_mention
      yield group, group.users
    end

  end

  # TODO: Move to post-analyzer?
  def extract_mentions(post)
    mentions = post.raw_mentions

    return unless mentions && mentions.length > 0

    groups = Group.where('LOWER(name) IN (?)', mentions)
    mentions -= groups.map(&:name).map(&:downcase)

    return [groups, nil] unless mentions && mentions.length > 0

    users = User.where(username_lower: mentions).where.not(id: post.user_id)

    [groups, users]
  end


  # TODO: Move to post-analyzer?
  # Returns a list of users who were quoted in the post
  def extract_quoted_users(post)
    post.raw.scan(/\[quote=\"([^,]+),.+\"\]/).uniq.map do |m|
      User.find_by("username_lower = :username AND id != :id", username: m.first.strip.downcase, id: post.user_id)
    end.compact
  end

  def extract_linked_users(post)
    post.topic_links.where(reflection: false).map do |link|
      linked_post = link.link_post
      if !linked_post && topic = link.link_topic
        linked_post = topic.posts(post_number: 1).first
      end
      (linked_post && post.user_id != linked_post.user_id && linked_post.user) || nil
    end.compact
  end

  # Notify a bunch of users
  def notify_non_pm_users(users, type, post, opts=nil)

    return if post.topic.try(:private_message?)

    users = [users] unless users.is_a?(Array)

    users.each do |u|
      create_notification(u, Notification.types[type], post, opts)
    end
  end

  def notify_post_users(post, notified)
    notify = TopicUser.where(topic_id: post.topic_id)
                      .where(notification_level: TopicUser.notification_levels[:watching])

    exclude_user_ids = notified.map(&:id)
    notify = notify.where("user_id NOT IN (?)", exclude_user_ids) if exclude_user_ids.present?

    notify.includes(:user).each do |tu|
      create_notification(tu.user, Notification.types[:posted], post)
    end
  end

end
