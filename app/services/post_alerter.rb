# frozen_string_literal: true

class PostAlerter
  USER_BATCH_SIZE = 100

  def self.post_created(post, opts = {})
    PostAlerter.new(opts).after_save_post(post, true)
    post
  end

  def initialize(default_opts = {})
    @default_opts = default_opts
  end

  def not_allowed?(user, post)
    user.blank? ||
    user.bot? ||
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

  def only_allowed_users(users, post)
    return users unless post.topic.private_message?
    users.select { |u| all_allowed_users(post).include?(u) }
  end

  def notify_about_reply?(post)
    # small actions can be whispers in this case they will have an action code
    # we never want to notify on this
    post.post_type == Post.types[:regular] ||
      (post.post_type == Post.types[:whisper] && post.action_code.nil?)
  end

  def after_save_post(post, new_record = false)
    notified = [post.user, post.last_editor].uniq

    # mentions (users/groups)
    mentioned_groups, mentioned_users = extract_mentions(post)

    if mentioned_groups || mentioned_users
      mentioned_opts = {}
      editor = post.last_editor

      if post.last_editor_id != post.user_id
        # Mention comes from an edit by someone else, so notification should say who added the mention.
        mentioned_opts = { user_id: editor.id, original_username: editor.username, display_username: editor.username }
      end

      expand_group_mentions(mentioned_groups, post) do |group, users|
        users = only_allowed_users(users, post)
        notified += notify_users(users - notified, :group_mentioned, post, mentioned_opts.merge(group: group))
      end

      if mentioned_users
        mentioned_users = only_allowed_users(mentioned_users, post)
        notified += notify_users(mentioned_users - notified, :mentioned, post, mentioned_opts)
      end
    end

    # replies
    reply_to_user = post.reply_notification_target

    if new_record && reply_to_user && !notified.include?(reply_to_user) && notify_about_reply?(post)
      notified += notify_non_pm_users(reply_to_user, :replied, post)
    end

    # quotes
    quoted_users = extract_quoted_users(post)
    notified += notify_non_pm_users(quoted_users - notified, :quoted, post)

    # linked
    linked_users = extract_linked_users(post)
    notified += notify_non_pm_users(linked_users - notified, :linked, post)

    # private messages
    if new_record
      if post.topic.private_message?
        notify_pm_users(post, reply_to_user, notified)
      elsif notify_about_reply?(post)
        notify_post_users(post, notified)
      end
    end

    sync_group_mentions(post, mentioned_groups)

    if new_record && post.post_number == 1
      topic = post.topic

      if topic.present?
        watchers = category_watchers(topic) + tag_watchers(topic) + group_watchers(topic)
        notify_first_post_watchers(post, watchers)
      end
    end
  end

  def group_watchers(topic)
    GroupUser.where(
      group_id: topic.allowed_groups.pluck(:group_id),
      notification_level: GroupUser.notification_levels[:watching_first_post]
    ).pluck(:user_id)
  end

  def tag_watchers(topic)
    topic.tag_users
      .where(notification_level: TagUser.notification_levels[:watching_first_post])
      .pluck(:user_id)
  end

  def category_watchers(topic)
    topic.category_users
      .where(notification_level: CategoryUser.notification_levels[:watching_first_post])
      .pluck(:user_id)
  end

  def notify_first_post_watchers(post, user_ids)
    return if user_ids.blank?
    user_ids.uniq!

    warn_if_not_sidekiq

    # Don't notify the OP
    user_ids -= [post.user_id]
    users = User.where(id: user_ids)

    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    each_user_in_batches(users) do |user|
      create_notification(user, Notification.types[:watching_first_post], post)
    end
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

  def destroy_notifications(user, types, topic)
    return if user.blank?
    return unless Guardian.new(user).can_see?(topic)

    User.transaction do
      user.notifications.where(
        notification_type: types,
        topic_id: topic.id
      ).destroy_all

      # Reload so notification counts sync up correctly
      user.reload
    end
  end

  NOTIFIABLE_TYPES = [:mentioned, :replied, :quoted, :posted, :linked, :private_message, :group_mentioned, :watching_first_post].map { |t|
    Notification.types[t]
  }

  def group_stats(topic)
    sql = <<~SQL
      SELECT COUNT(*) FROM topics t
      JOIN topic_allowed_groups g ON g.group_id = :group_id AND g.topic_id = t.id
      LEFT JOIN group_archived_messages a ON a.topic_id = t.id AND a.group_id = g.group_id
      WHERE a.id IS NULL AND t.deleted_at is NULL AND t.archetype = 'private_message'
    SQL

    topic.allowed_groups.map do |g|
      {
        group_id: g.id,
        group_name: g.name.downcase,
        inbox_count: DB.query_single(sql, group_id: g.id).first.to_i
      }
    end
  end

  def notify_group_summary(user, post)
    @group_stats ||= {}
    stats = (@group_stats[post.topic_id] ||= group_stats(post.topic))
    return unless stats

    group_id = post.topic
      .topic_allowed_groups
      .where(group_id: user.groups.pluck(:id))
      .pluck_first(:group_id)

    stat = stats.find { |s| s[:group_id] == group_id }
    return unless stat && stat[:inbox_count] > 0

    notification_type = Notification.types[:group_message_summary]

    DistributedMutex.synchronize("group_message_notify_#{user.id}") do
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
    end

    # TODO decide if it makes sense to also publish a desktop notification
  end

  def should_notify_edit?(notification, post, opts)
    notification.data_hash["display_username"] != (opts[:display_username].presence || post.user.username)
  end

  def should_notify_like?(user, notification)
    return true if user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:always]
    return true if user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:first_time_and_daily] && notification.created_at < 1.day.ago
    false
  end

  def should_notify_previous?(user, post, notification, opts)
    case notification.notification_type
    when Notification.types[:edited] then should_notify_edit?(notification, post, opts)
    when Notification.types[:liked]  then should_notify_like?(user, notification)
    else false
    end
  end

  COLLAPSED_NOTIFICATION_TYPES ||= [
    Notification.types[:replied],
    Notification.types[:posted],
    Notification.types[:private_message],
  ]

  def create_notification(user, type, post, opts = {})
    opts = @default_opts.merge(opts)

    DiscourseEvent.trigger(:before_create_notification, user, type, post, opts)

    return if user.blank? || user.bot?
    return if (topic = post.topic).blank?

    is_liked = type == Notification.types[:liked]
    return if is_liked && user.user_option.like_notification_frequency == UserOption.like_notification_frequency_type[:never]

    # Make sure the user can see the post
    return unless Guardian.new(user).can_see?(post)

    return if user.staged? && topic.category&.mailinglist_mirror?

    notifier_id = opts[:user_id] || post.user_id # xxxxx look at revision history

    # apply muting here
    return if notifier_id && MutedUser.where(user_id: user.id, muted_user_id: notifier_id)
      .joins(:muted_user)
      .where('NOT admin AND NOT moderator')
      .exists?

    # apply ignored here
    return if notifier_id && IgnoredUser.where(user_id: user.id, ignored_user_id: notifier_id)
      .joins(:ignored_user)
      .where('NOT admin AND NOT moderator')
      .exists?

    # skip if muted on the topic
    return if TopicUser.where(
      topic: topic,
      user: user,
      notification_level: TopicUser.notification_levels[:muted]
    ).exists?

    # skip if muted on the group
    if group = opts[:group]
      return if GroupUser.where(
        group_id: opts[:group_id],
        user_id: user.id,
        notification_level: TopicUser.notification_levels[:muted]
      ).exists?
    end

    existing_notifications = user.notifications
      .order("notifications.id DESC")
      .where(
        topic_id: post.topic_id,
        post_number: post.post_number
      ).limit(10)

    # Don't notify the same user about the same type of notification on the same post
    existing_notification_of_same_type = existing_notifications.find { |n| n.notification_type == type }

    return if existing_notification_of_same_type && !should_notify_previous?(user, post, existing_notification_of_same_type, opts)

    notification_data = {}

    if is_liked &&
      existing_notification_of_same_type &&
      existing_notification_of_same_type.created_at > 1.day.ago &&
      (
        user.user_option.like_notification_frequency ==
        UserOption.like_notification_frequency_type[:always]
      )

      data = existing_notification_of_same_type.data_hash
      notification_data["username2"] = data["display_username"]
      notification_data["count"] = (data["count"] || 1).to_i + 1
      # don't use destroy so we don't trigger a notification count refresh
      Notification.where(id: existing_notification_of_same_type.id).destroy_all
    end

    collapsed = false

    if COLLAPSED_NOTIFICATION_TYPES.include?(type)
      destroy_notifications(user, COLLAPSED_NOTIFICATION_TYPES, topic)
      collapsed = true
    end

    original_post = post
    original_username = opts[:display_username].presence || post.username

    if collapsed
      post = first_unread_post(user, topic) || post
      count = unread_count(user, topic)
      if count > 1
        I18n.with_locale(user.effective_locale) do
          opts[:display_username] = I18n.t('embed.replies', count: count)
        end
      end
    end

    UserActionManager.notification_created(original_post, user, type, opts[:acting_user_id])

    topic_title = topic.title
    # when sending a private message email, keep the original title
    if topic.private_message? && modifications = post.revisions.map(&:modifications)
      if first_title_modification = modifications.find { |m| m.has_key?("title") }
        topic_title = first_title_modification["title"][0]
      end
    end

    notification_data.merge!(topic_title: topic_title,
                             original_post_id: original_post.id,
                             original_post_type: original_post.post_type,
                             original_username: original_username,
                             revision_number: opts[:revision_number],
                             display_username: opts[:display_username] || post.user.username)

    if group = opts[:group]
      notification_data[:group_id] = group.id
      notification_data[:group_name] = group.name
    end

    if original_post.via_email && (incoming_email = original_post.incoming_email)
      skip_send_email = contains_email_address?(incoming_email.to_addresses, user) ||
        contains_email_address?(incoming_email.cc_addresses, user)
    else
      skip_send_email = opts[:skip_send_email]
    end

    # Create the notification
    created = user.notifications.create!(
      notification_type: type,
      topic_id: post.topic_id,
      post_number: post.post_number,
      post_action_id: opts[:post_action_id],
      data: notification_data.to_json,
      skip_send_email: skip_send_email
    )

    if created.id && existing_notifications.empty? && NOTIFIABLE_TYPES.include?(type) && !user.suspended?
      create_notification_alert(user: user, post: original_post, notification_type: type, username: original_username)
    end

    created.id ? created : nil
  end

  def create_notification_alert(user:, post:, notification_type:, excerpt: nil, username: nil)
    if post_url = post.url
      payload = {
       notification_type: notification_type,
       post_number: post.post_number,
       topic_title: post.topic.title,
       topic_id: post.topic.id,
       excerpt: excerpt || post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true),
       username: username || post.username,
       post_url: post_url
      }

      DiscourseEvent.trigger(:pre_notification_alert, user, payload)
      MessageBus.publish("/notification-alert/#{user.id}", payload, user_ids: [user.id])
      push_notification(user, payload)
      DiscourseEvent.trigger(:post_notification_alert, user, payload)
    end
  end

  def contains_email_address?(addresses, user)
    return false if addresses.blank?
    addresses.split(";").include?(user.email)
  end

  def push_notification(user, payload)
    if user.push_subscriptions.exists?
      Jobs.enqueue(:send_push_notification, user_id: user.id, payload: payload)
    end

    if SiteSetting.allow_user_api_key_scopes.split("|").include?("push") && SiteSetting.allowed_user_api_push_urls.present?
      clients = user.user_api_keys
        .where("('push' = ANY(scopes) OR 'notifications' = ANY(scopes))")
        .where("push_url IS NOT NULL AND push_url <> ''")
        .where("position(push_url IN ?) > 0", SiteSetting.allowed_user_api_push_urls)
        .where("revoked_at IS NULL")
        .pluck(:client_id, :push_url)

      if clients.length > 0
        Jobs.enqueue(:push_notification, clients: clients, payload: payload, user_id: user.id)
      end
    end
  end

  def expand_group_mentions(groups, post)
    return unless post.user && groups

    Group.mentionable(post.user, include_public: false).where(id: groups.map(&:id)).each do |group|
      next if group.user_count >= SiteSetting.max_users_notified_per_group_mention
      yield group, group.users
    end

  end

  # TODO: Move to post-analyzer?
  def extract_mentions(post)
    mentions = post.raw_mentions
    return if mentions.blank?

    groups = Group.where('LOWER(name) IN (?)', mentions)
    mentions -= groups.map(&:name).map(&:downcase)
    groups = nil if groups.empty?

    if mentions.present?
      users = User.where(username_lower: mentions).where.not(id: post.user_id)
      users = nil if users.empty?
    end

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
        linked_post = topic.posts.find_by(post_number: 1)
      end
      (linked_post && post.user_id != linked_post.user_id && linked_post.user) || nil
    end.compact
  end

  # Notify a bunch of users
  def notify_non_pm_users(users, type, post, opts = {})
    return [] if post.topic&.private_message?

    notify_users(users, type, post, opts)
  end

  def notify_users(users, type, post, opts = {})
    users = [users] unless users.is_a?(Array)
    users.reject!(&:staged?) if post.topic&.private_message?

    warn_if_not_sidekiq

    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    users.each do |u|
      create_notification(u, Notification.types[type], post, opts)
    end

    users
  end

  def notify_pm_users(post, reply_to_user, notified)
    return unless post.topic

    warn_if_not_sidekiq

    # users that aren't part of any mentioned groups
    users = directly_targeted_users(post).reject { |u| notified.include?(u) }
    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    users.each do |user|
      notification_level = TopicUser.get(post.topic, user)&.notification_level
      if reply_to_user == user || notification_level == TopicUser.notification_levels[:watching] || user.staged?
        create_notification(user, Notification.types[:private_message], post)
      end
    end

    # users that are part of all mentionned groups
    users = indirectly_targeted_users(post).reject { |u| notified.include?(u) }
    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    users.each do |user|
      case TopicUser.get(post.topic, user)&.notification_level
      when TopicUser.notification_levels[:watching]
        # only create a notification when watching the group
        create_notification(user, Notification.types[:private_message], post)
      when TopicUser.notification_levels[:tracking]
        notify_group_summary(user, post)
      end
    end
  end

  def notify_post_users(post, notified, include_category_watchers: true, include_tag_watchers: true)
    return unless post.topic

    warn_if_not_sidekiq

    condition = +<<~SQL
      id IN (
        SELECT user_id
          FROM topic_users
         WHERE notification_level = :watching
           AND topic_id = :topic_id
         /*category*/
         /*tags*/
      )
    SQL

    if include_category_watchers
      condition.sub! "/*category*/", <<~SQL
        UNION

        SELECT cu.user_id
          FROM category_users cu
     LEFT JOIN topic_users tu ON tu.user_id = cu.user_id
                             AND tu.topic_id = :topic_id
         WHERE cu.notification_level = :watching
           AND cu.category_id = :category_id
           AND tu.user_id IS NULL
      SQL
    end

    tag_ids = post.topic.topic_tags.pluck('topic_tags.tag_id')

    if include_tag_watchers && tag_ids.present?
      condition.sub! "/*tags*/", <<~SQL
        UNION

        SELECT tag_users.user_id
          FROM tag_users
     LEFT JOIN topic_users tu ON tu.user_id = tag_users.user_id
                             AND tu.topic_id = :topic_id
         WHERE tag_users.notification_level = :watching
           AND tag_users.tag_id IN (:tag_ids)
           AND tu.user_id IS NULL
      SQL
    end

    notify = User.where(condition,
      watching: TopicUser.notification_levels[:watching],
      topic_id: post.topic_id,
      category_id: post.topic.category_id,
      tag_ids: tag_ids
    )

    exclude_user_ids = notified.map(&:id)
    notify = notify.where("id NOT IN (?)", exclude_user_ids) if exclude_user_ids.present?

    DiscourseEvent.trigger(:before_create_notifications_for_users, notify, post)

    already_seen_user_ids = Set.new TopicUser.where(topic_id: post.topic.id).where("highest_seen_post_number >= ?", post.post_number).pluck(:user_id)

    each_user_in_batches(notify) do |user|
      notification_type = already_seen_user_ids.include?(user.id) ? Notification.types[:edited] : Notification.types[:posted]
      create_notification(user, notification_type, post)
    end
  end

  def warn_if_not_sidekiq
    Rails.logger.warn("PostAlerter.#{caller_locations(1, 1)[0].label} was called outside of sidekiq") unless Sidekiq.server?
  end

  private

  def each_user_in_batches(users)
    # This is race-condition-safe, unlike #find_in_batches
    users.pluck(:id).each_slice(USER_BATCH_SIZE) do |user_ids_batch|
      User.where(id: user_ids_batch).each { |user| yield(user) }
    end
  end
end
