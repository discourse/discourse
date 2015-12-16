class PostAlerter

  def self.post_created(post)
    alerter = PostAlerter.new
    alerter.after_save_post(post, true)
    post
  end

  def allowed_users(post)
    post.topic.all_allowed_users.reject do |user|
      user.blank? ||
      user.id == Discourse::SYSTEM_USER_ID ||
      user.id == post.user_id
    end
  end

  def after_save_post(post, new_record = false)
    notified = [post.user].compact

    if new_record && post.topic.private_message?
      # If it's a private message, notify the topic_allowed_users
      allowed_users(post).each do |user|
        case TopicUser.get(post.topic, user).try(:notification_level)
        when TopicUser.notification_levels[:tracking]
          next unless post.reply_to_post_number || post.reply_to_post.try(:user_id) == user.id
        when TopicUser.notification_levels[:regular]
          next unless post.reply_to_post.try(:user_id) == user.id
        when TopicUser.notification_levels[:muted]
          notified += [user]
          next
        end
        create_notification(user, Notification.types[:private_message], post)
        notified += [user]
      end
    end

    reply_to_user = post.reply_notification_target

    if new_record && reply_to_user && post.post_type == Post.types[:regular]
      notify_users(reply_to_user, :replied, post)
    end

    if reply_to_user
      notified += [reply_to_user]
    end

    mentioned_groups, mentioned_users = extract_mentions(post)

    quoted_users = extract_quoted_users(post)
    linked_users = extract_linked_users(post)

    expand_group_mentions(mentioned_groups, post) do |group, users|
      notify_users(users - notified, :group_mentioned, post, group: group)
      notified += users
    end

    if mentioned_users
      notify_users(mentioned_users - notified, :mentioned, post)
      notified += mentioned_users
    end

    notify_users(quoted_users - notified, :quoted, post)
    notified += quoted_users

    notify_users(linked_users - notified, :linked, post)

    if new_record && post.post_type == Post.types[:regular]
      # If it's not a private message and it's not an automatic post caused by a moderator action, notify the users
      notify_post_users(post, notified)
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

  def create_notification(user, type, post, opts=nil)
    return if user.blank?
    return if user.id == Discourse::SYSTEM_USER_ID

    opts ||= {}

    # Make sure the user can see the post
    return unless Guardian.new(user).can_see?(post)

    notifier_id = opts[:user_id] || post.user_id

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
                                .order("notifications.id desc")
                                .find_by(topic_id: post.topic_id,
                                         post_number: post.post_number,
                                         notification_type: type)

    if existing_notification && existing_notification.notification_type == type
       return unless existing_notification.notification_type == Notification.types[:edited] &&
                     existing_notification.data_hash["display_username"] = opts[:display_username]
    end

    collapsed = false

    if type == Notification.types[:replied] || type == Notification.types[:posted]
      destroy_notifications(user, Notification.types[:replied] , post.topic)
      destroy_notifications(user, Notification.types[:posted] , post.topic)
      collapsed = true
    end

    if type == Notification.types[:private_message]
      destroy_notifications(user, type, post.topic)
      collapsed = true
    end

    original_post = post
    original_username = opts[:display_username] || post.username

    if collapsed
      post = first_unread_post(user,post.topic) || post
      count = unread_count(user, post.topic)
      I18n.with_locale(user.effective_locale) do
        opts[:display_username] = I18n.t('embed.replies', count: count) if count > 1
      end
    end

    UserActionObserver.log_notification(original_post, user, type, opts[:acting_user_id])

    notification_data = {
      topic_title: post.topic.title,
      original_post_id: original_post.id,
      original_username: original_username,
      display_username: opts[:display_username] || post.user.username
    }

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

   if (!existing_notification) && NOTIFIABLE_TYPES.include?(type)

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

    groups = Group.where('lower(name) in (?)', mentions)
    mentions -= groups.map(&:name).map(&:downcase)

    return [groups, nil] unless mentions && mentions.length > 0

    users = User.where(username_lower: mentions).where("id <> ?", post.user_id)

    [groups,users]
  end


  # TODO: Move to post-analyzer?
  # Returns a list of users who were quoted in the post
  def extract_quoted_users(post)
    post.raw.scan(/\[quote=\"([^,]+),.+\"\]/).uniq.map do |m|
      User.find_by("username_lower = :username and id != :id", username: m.first.strip.downcase, id: post.user_id)
    end.compact
  end

  def extract_linked_users(post)
    post.topic_links.where(reflection: false).map do |link|
      linked_post = link.link_post
      if !linked_post && topic = link.link_topic
        linked_post = topic.posts(post_number: 1).first
      end
      linked_post && post.user_id != linked_post.user_id && linked_post.user
    end.compact
  end

  # Notify a bunch of users
  def notify_users(users, type, post, opts=nil)
    users = [users] unless users.is_a?(Array)

    if post.topic.try(:private_message?)
      whitelist = allowed_users(post)
      users.reject! {|u| !whitelist.include?(u)}
    end

    users.each do |u|
      create_notification(u, Notification.types[type], post, opts)
    end
  end

  def notify_post_users(post, notified)

    exclude_user_ids = notified.map(&:id)

    notify = TopicUser.where(topic_id: post.topic_id)
             .where(notification_level: TopicUser.notification_levels[:watching])

    notify = notify.where("user_id NOT IN (?)", exclude_user_ids) if exclude_user_ids.present?

    notify.includes(:user).each do |tu|
        create_notification(tu.user, Notification.types[:posted], post)
      end
  end

end
