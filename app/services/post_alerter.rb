# frozen_string_literal: true

class PostAlerter
  USER_BATCH_SIZE = 100

  def self.post_created(post, opts = {})
    PostAlerter.new(opts).after_save_post(post, true)
    post
  end

  def self.post_edited(post, opts = {})
    PostAlerter.new(opts).after_save_post(post, false)
    post
  end

  def self.create_notification_alert(
    user:,
    post:,
    notification_type:,
    excerpt: nil,
    username: nil,
    group_name: nil
  )
    return if user.suspended?

    if post_url = post.url
      payload = {
        notification_type: notification_type,
        post_number: post.post_number,
        topic_title: post.topic.title,
        topic_id: post.topic.id,
        excerpt:
          excerpt ||
            post.excerpt(
              400,
              text_entities: true,
              strip_links: true,
              remap_emoji: true,
              plain_hashtags: true,
            ),
        username: username || post.username,
        post_url: post_url,
      }
      payload[:group_name] = group_name if group_name.present?

      DiscourseEvent.trigger(:pre_notification_alert, user, payload)

      if user.allow_live_notifications?
        send_notification =
          DiscoursePluginRegistry.push_notification_filters.all? do |filter|
            filter.call(user, payload)
          end

        if send_notification
          payload =
            DiscoursePluginRegistry.apply_modifier(
              :post_alerter_live_notification_payload,
              payload,
              user,
            )
          MessageBus.publish("/notification-alert/#{user.id}", payload, user_ids: [user.id])
        end
      end

      push_notification(user, payload)

      # deprecated. use push_notification instead
      DiscourseEvent.trigger(:post_notification_alert, user, payload)
    end
  end

  def self.push_notification(user, payload)
    return if user.do_not_disturb?

    # This DiscourseEvent needs to be independent of the push_notification_filters for some use cases.
    # If the subscriber of this event wants to filter usage by push_notification_filters as well,
    # implement same logic as below (`if DiscoursePluginRegistry.push_notification_filters.any?...`)
    DiscourseEvent.trigger(:push_notification, user, payload)

    if DiscoursePluginRegistry.push_notification_filters.any? { |filter|
         !filter.call(user, payload)
       }
      return
    end

    push_window = SiteSetting.push_notification_time_window_mins
    if push_window > 0 && user.seen_since?(push_window.minutes.ago)
      delay = (push_window - (Time.now - user.last_seen_at) / 60)
    end

    if user.push_subscriptions.exists?
      if delay.present?
        Jobs.enqueue_in(delay.minutes, :send_push_notification, user_id: user.id, payload: payload)
      else
        Jobs.enqueue(:send_push_notification, user_id: user.id, payload: payload)
      end
    end

    if SiteSetting.allow_user_api_key_scopes.split("|").include?("push") &&
         SiteSetting.allowed_user_api_push_urls.present?
      clients =
        user
          .user_api_keys
          .joins(:scopes)
          .where("user_api_key_scopes.name IN ('push', 'notifications')")
          .where("push_url IS NOT NULL AND push_url <> ''")
          .where("position(push_url IN ?) > 0", SiteSetting.allowed_user_api_push_urls)
          .where("revoked_at IS NULL")
          .order(client_id: :asc)
          .pluck(:client_id, :push_url)

      return if clients.length == 0

      if delay.present?
        Jobs.enqueue_in(
          delay.minutes,
          :push_notification,
          clients: clients,
          payload: payload,
          user_id: user.id,
        )
      else
        Jobs.enqueue(:push_notification, clients: clients, payload: payload, user_id: user.id)
      end
    end
  end

  def initialize(default_opts = {})
    @default_opts = default_opts
  end

  def not_allowed?(user, post)
    user.blank? || user.bot? || user.id == post.user_id
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

    DiscourseEvent.trigger(:post_alerter_before_mentions, post, new_record, notified)

    # mentions (users/groups)
    mentioned_groups, mentioned_users, mentioned_here = extract_mentions(post)

    if mentioned_groups || mentioned_users || mentioned_here
      mentioned_opts = {}
      editor = post.last_editor

      if post.last_editor_id != post.user_id
        # Mention comes from an edit by someone else, so notification should say who added the mention.
        mentioned_opts = {
          user_id: editor.id,
          original_username: editor.username,
          display_username: editor.username,
        }
      end

      if mentioned_users
        mentioned_users = only_allowed_users(mentioned_users, post)
        mentioned_users = mentioned_users - pm_watching_users(post)
        notified += notify_users(mentioned_users - notified, :mentioned, post, mentioned_opts)
      end

      expand_group_mentions(mentioned_groups, post) do |group, users|
        users = only_allowed_users(users, post)
        to_notify =
          DiscoursePluginRegistry.apply_modifier(
            :expand_group_mention_users,
            users - notified,
            group,
          )

        notified +=
          notify_users(to_notify, :group_mentioned, post, mentioned_opts.merge(group: group))
      end

      if mentioned_here
        users = expand_here_mention(post, exclude_ids: notified.map(&:id))
        users = only_allowed_users(users, post)
        notified += notify_users(users - notified, :mentioned, post, mentioned_opts)
      end
    end

    DiscourseEvent.trigger(:post_alerter_before_replies, post, new_record, notified)

    # replies
    reply_to_user = post.reply_notification_target

    if new_record && notify_about_reply?(post)
      if reply_to_user && !notified.include?(reply_to_user)
        notified += notify_non_pm_users(reply_to_user, :replied, post)
      end

      topic_author = post.topic.user
      if topic_author && !notified.include?(topic_author) &&
           user_watching_topic?(topic_author, post.topic)
        notified += notify_non_pm_users(topic_author, :replied, post)
      end
    end

    DiscourseEvent.trigger(:post_alerter_before_quotes, post, new_record, notified)

    # quotes
    quoted_users = extract_quoted_users(post)
    notified += notify_non_pm_users(quoted_users - notified, :quoted, post)

    DiscourseEvent.trigger(:post_alerter_before_linked, post, new_record, notified)

    # linked
    linked_users = extract_linked_users(post)
    notified += notify_non_pm_users(linked_users - notified, :linked, post)

    DiscourseEvent.trigger(:post_alerter_before_post, post, new_record, notified)

    notified = notified + category_or_tag_muters(post.topic)

    if new_record
      if post.topic.private_message?
        # private messages
        notified += notify_pm_users(post, reply_to_user, quoted_users, notified, new_record)
      elsif notify_about_reply?(post)
        # posts
        notified +=
          notify_post_users(
            post,
            notified,
            new_record: new_record,
            include_category_watchers: false,
            include_tag_watchers: false,
          )
        notified +=
          notify_post_users(
            post,
            notified,
            new_record: new_record,
            include_topic_watchers: false,
            notification_type: :watching_category_or_tag,
          )
      end
    end

    sync_group_mentions(post, mentioned_groups)

    DiscourseEvent.trigger(:post_alerter_before_first_post, post, new_record, notified)

    if new_record && post.post_number == 1
      topic = post.topic

      if topic.present?
        watchers = category_watchers(topic) + tag_watchers(topic) + group_watchers(topic)
        # Notify only users who can see the topic
        watchers &= topic.all_allowed_users.pluck(:id) if post.topic.private_message?
        notified += notify_first_post_watchers(post, watchers, notified)
      end
    end

    DiscourseEvent.trigger(:post_alerter_after_save_post, post, new_record, notified)
  end

  def group_watchers(topic)
    GroupUser.where(
      group_id: topic.allowed_groups.pluck(:group_id),
      notification_level: GroupUser.notification_levels[:watching_first_post],
    ).pluck(:user_id)
  end

  def tag_watchers(topic)
    topic
      .tag_users
      .notification_level_visible([TagUser.notification_levels[:watching_first_post]])
      .distinct(:user_id)
      .pluck(:user_id)
  end

  def category_watchers(topic)
    topic
      .category_users
      .where(notification_level: CategoryUser.notification_levels[:watching_first_post])
      .pluck(:user_id)
  end

  def category_or_tag_muters(topic)
    user_option_condition_sql_fragment =
      if SiteSetting.watched_precedence_over_muted
        "uo.watched_precedence_over_muted IS false"
      else
        "(uo.watched_precedence_over_muted IS NULL OR uo.watched_precedence_over_muted IS false)"
      end

    user_ids_sql = <<~SQL
        SELECT uo.user_id FROM user_options uo
        LEFT JOIN topic_users tus ON tus.user_id = uo.user_id AND tus.topic_id = #{topic.id}
        LEFT JOIN category_users cu ON cu.user_id = uo.user_id AND cu.category_id = #{topic.category_id.to_i}
        LEFT JOIN tag_users tu ON tu.user_id = uo.user_id
        JOIN topic_tags tt ON tt.tag_id = tu.tag_id AND tt.topic_id = #{topic.id}
        WHERE
          (tus.id IS NULL OR tus.notification_level != #{TopicUser.notification_levels[:watching]})
          AND (cu.notification_level = #{CategoryUser.notification_levels[:muted]} OR tu.notification_level = #{TagUser.notification_levels[:muted]})
          AND #{user_option_condition_sql_fragment}
        SQL

    User.where("id IN (#{user_ids_sql})")
  end

  def notify_first_post_watchers(post, user_ids, notified = nil)
    return [] if user_ids.blank?
    user_ids.uniq!

    warn_if_not_sidekiq

    # Don't notify the OP and last editor
    user_ids -= [post.user_id, post.last_editor_id]
    users = User.where(id: user_ids).includes(:do_not_disturb_timings)
    users = users.where.not(id: notified.map(&:id)) if notified.present?

    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    each_user_in_batches(users) do |user|
      create_notification(user, Notification.types[:watching_first_post], post)
    end

    users
  end

  def sync_group_mentions(post, mentioned_groups)
    GroupMention.where(post_id: post.id).destroy_all
    return if mentioned_groups.blank?

    now = Time.zone.now

    # insert_all instead of insert_all! since multiple post_alert jobs might be
    # running concurrently
    GroupMention.insert_all(
      mentioned_groups.map do |group|
        { post_id: post.id, group_id: group.id, created_at: now, updated_at: now }
      end,
    )
  end

  def unread_posts(user, topic)
    Post
      .secured(Guardian.new(user))
      .where(
        "post_number > COALESCE((
               SELECT last_read_post_number FROM topic_users tu
               WHERE tu.user_id = ? AND tu.topic_id = ? ),0)",
        user.id,
        topic.id,
      )
      .where(
        "reply_to_user_id = :user_id
        OR exists(SELECT 1 from topic_users tu
                  WHERE tu.user_id = :user_id AND
                    tu.topic_id = :topic_id AND
                    notification_level = :topic_level)
        OR exists(SELECT 1 from category_users cu
                  WHERE cu.user_id = :user_id AND
                    cu.category_id = :category_id AND
                    notification_level = :category_level)
        OR exists(SELECT 1 from tag_users tu
                  WHERE tu.user_id = :user_id AND
                    tu.tag_id IN (SELECT tag_id FROM topic_tags WHERE topic_id = :topic_id) AND
                    notification_level = :tag_level)",
        user_id: user.id,
        topic_id: topic.id,
        category_id: topic.category_id,
        topic_level: TopicUser.notification_levels[:watching],
        category_level: CategoryUser.notification_levels[:watching],
        tag_level: TagUser.notification_levels[:watching],
      )
      .where(topic_id: topic.id)
  end

  def first_unread_post(user, topic)
    unread_posts(user, topic).order("post_number").first
  end

  def unread_count(user, topic)
    unread_posts(user, topic).count
  end

  def destroy_notifications(user, types, topic)
    return if user.blank?
    return unless Guardian.new(user).can_see?(topic)

    User.transaction do
      user.notifications.where(notification_type: types, topic_id: topic.id).destroy_all

      # Reload so notification counts sync up correctly
      user.reload
    end
  end

  NOTIFIABLE_TYPES =
    %i[
      mentioned
      replied
      quoted
      posted
      linked
      private_message
      group_mentioned
      watching_first_post
      watching_category_or_tag
      event_reminder
      event_invitation
    ].map { |t| Notification.types[t] }

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
        group_name: g.name,
        inbox_count: DB.query_single(sql, group_id: g.id).first.to_i,
      }
    end
  end

  def notify_group_summary(user, topic, acting_user_id: nil)
    @group_stats ||= {}
    stats = (@group_stats[topic.id] ||= group_stats(topic))
    return unless stats

    group_id = topic.topic_allowed_groups.where(group_id: user.groups).pick(:group_id)

    stat = stats.find { |s| s[:group_id] == group_id }
    return unless stat

    DistributedMutex.synchronize("group_message_notify_#{user.id}") do
      if stat[:inbox_count] > 0
        Notification.consolidate_or_create!(
          notification_type: Notification.types[:group_message_summary],
          user_id: user.id,
          read: user.id === acting_user_id ? true : false,
          data: {
            group_id: stat[:group_id],
            group_name: stat[:group_name],
            inbox_count: stat[:inbox_count],
            username: user.username_lower,
          }.to_json,
        )
      else
        Notification
          .where(user_id: user.id, notification_type: Notification.types[:group_message_summary])
          .where("data::json ->> 'group_id' = ?", stat[:group_id].to_s)
          .delete_all
      end
    end

    # TODO decide if it makes sense to also publish a desktop notification
  end

  def should_notify_edit?(notification, post, opts)
    notification.created_at < 1.day.ago ||
      notification.data_hash["display_username"] !=
        (opts[:display_username].presence || post.user.username)
  end

  def should_notify_like?(user, notification)
    if user.user_option.like_notification_frequency ==
         UserOption.like_notification_frequency_type[:always]
      return true
    end
    if user.user_option.like_notification_frequency ==
         UserOption.like_notification_frequency_type[:first_time_and_daily] &&
         notification.created_at < 1.day.ago
      return true
    end
    false
  end

  def should_notify_previous?(user, post, notification, opts)
    case notification.notification_type
    when Notification.types[:edited]
      should_notify_edit?(notification, post, opts)
    when Notification.types[:liked]
      should_notify_like?(user, notification)
    else
      false
    end
  end

  COLLAPSED_NOTIFICATION_TYPES = [
    Notification.types[:replied],
    Notification.types[:posted],
    Notification.types[:private_message],
    Notification.types[:watching_category_or_tag],
  ]

  def create_notification(user, type, post, opts = {})
    opts = @default_opts.merge(opts)

    DiscourseEvent.trigger(:before_create_notification, user, type, post, opts)

    return if user.blank? || user.bot? || post.blank?
    return if (topic = post.topic).blank?

    is_liked = type == Notification.types[:liked]
    if is_liked &&
         user.user_option.like_notification_frequency ==
           UserOption.like_notification_frequency_type[:never]
      return
    end

    return if !Guardian.new(user).can_receive_post_notifications?(post)

    return if user.staged? && topic.category&.mailinglist_mirror?

    notifier_id = opts[:user_id] || post.user_id # xxxxx look at revision history
    if notifier_id &&
         UserCommScreener.new(
           acting_user_id: notifier_id,
           target_user_ids: user.id,
         ).ignoring_or_muting_actor?(user.id)
      return
    end

    # skip if muted on the topic
    if TopicUser.where(
         topic: topic,
         user: user,
         notification_level: TopicUser.notification_levels[:muted],
       ).exists?
      return
    end

    # skip if muted on the group
    if group = opts[:group]
      if GroupUser.where(
           group_id: opts[:group_id],
           user_id: user.id,
           notification_level: TopicUser.notification_levels[:muted],
         ).exists?
        return
      end
    end

    existing_notifications =
      user
        .notifications
        .order("notifications.id DESC")
        .where(topic_id: post.topic_id, post_number: post.post_number)
        .limit(10)

    # Don't notify the same user about the same type of notification on the same post
    existing_notification_of_same_type =
      existing_notifications.find { |n| n.notification_type == type }

    if existing_notification_of_same_type &&
         !should_notify_previous?(user, post, existing_notification_of_same_type, opts)
      return
    end

    # linked, quoted, mentioned, chat_quoted may be suppressed if you already have a reply notification
    if [
         Notification.types[:quoted],
         Notification.types[:linked],
         Notification.types[:mentioned],
         Notification.types[:chat_quoted],
       ].include?(type)
      if existing_notifications.find { |n| n.notification_type == Notification.types[:replied] }
        return
      end
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
          opts[:display_username] = I18n.t("embed.replies", count: count)
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

    notification_data = {
      topic_title: topic_title,
      original_post_id: original_post.id,
      original_post_type: original_post.post_type,
      original_username: original_username,
      revision_number: opts[:revision_number],
      display_username: opts[:display_username] || post.user.username,
    }

    opts[:custom_data].each { |k, v| notification_data[k] = v } if opts[:custom_data].is_a?(Hash)

    if group = opts[:group]
      notification_data[:group_id] = group.id
      notification_data[:group_name] = group.name
    end

    if opts[:skip_send_email_to]&.include?(user.email)
      skip_send_email = true
    elsif original_post.via_email && (incoming_email = original_post.incoming_email)
      skip_send_email =
        incoming_email.to_addresses_split.include?(user.email) ||
          incoming_email.cc_addresses_split.include?(user.email)
    else
      skip_send_email = opts[:skip_send_email]
    end

    # Create the notification
    notification_data =
      DiscoursePluginRegistry.apply_modifier(:notification_data, notification_data)

    created =
      user.notifications.consolidate_or_create!(
        notification_type: type,
        topic_id: post.topic_id,
        post_number: post.post_number,
        post_action_id: opts[:post_action_id],
        data: notification_data.to_json,
        skip_send_email: skip_send_email,
      )

    if created.id && existing_notifications.empty? && NOTIFIABLE_TYPES.include?(type)
      create_notification_alert(
        user: user,
        post: original_post,
        notification_type: type,
        username: original_username,
        group_name: group&.name,
      )
    end

    created.id ? created : nil
  end

  def create_notification_alert(
    user:,
    post:,
    notification_type:,
    excerpt: nil,
    username: nil,
    group_name: nil
  )
    self.class.create_notification_alert(
      user: user,
      post: post,
      notification_type: notification_type,
      excerpt: excerpt,
      username: username,
      group_name: group_name,
    )
  end

  def push_notification(user, payload)
    self.class.push_notification(user, payload)
  end

  def expand_group_mentions(groups, post)
    return unless post.user && groups

    Group
      .mentionable(post.user, include_public: false)
      .where(id: groups.map(&:id))
      .each do |group|
        next if group.user_count >= SiteSetting.max_users_notified_per_group_mention
        yield group, group.users
      end
  end

  def expand_here_mention(post, exclude_ids: nil)
    posts = Post.where(topic_id: post.topic_id)
    posts = posts.where.not(user_id: exclude_ids) if exclude_ids.present?

    if post.user.staff?
      posts = posts.where(post_type: [Post.types[:regular], Post.types[:whisper]])
    else
      posts = posts.where(post_type: Post.types[:regular])
    end

    User.real.where(id: posts.select(:user_id)).limit(SiteSetting.max_here_mentioned)
  end

  # TODO: Move to post-analyzer?
  def extract_mentions(post)
    mentions = post.raw_mentions
    return if mentions.blank?

    groups = Group.where("LOWER(name) IN (?)", mentions)
    mentions -= groups.map(&:name).map(&:downcase)
    groups = nil if groups.empty?

    if mentions.present?
      users =
        User
          .where(username_lower: mentions)
          .includes(:do_not_disturb_timings)
          .where.not(id: post.user_id)
      users = nil if users.empty?
    end

    # @here can be a user mention and then this feature is disabled
    here = mentions.include?(SiteSetting.here_mention) && Guardian.new(post.user).can_mention_here?

    [groups, users, here]
  end

  # TODO: Move to post-analyzer?
  # Returns a list of users who were quoted in the post
  def extract_quoted_users(post)
    usernames =
      if SiteSetting.display_name_on_posts && !SiteSetting.prioritize_username_in_ux
        post.raw.scan(/username:([[:alnum:]]*)"(?=\])/)
      else
        post.raw.scan(/\[quote=\"([^,]+),.+\"\]/)
      end.uniq.map { |q| q.first.strip.downcase }
    User.where.not(id: post.user_id).where(username_lower: usernames)
  end

  def extract_linked_users(post)
    users =
      post
        .topic_links
        .where(reflection: false)
        .map do |link|
          linked_post = link.link_post
          if !linked_post && topic = link.link_topic
            linked_post = topic.posts.find_by(post_number: 1)
          end
          (linked_post && post.user_id != linked_post.user_id && linked_post.user) || nil
        end
        .compact

    DiscourseEvent.trigger(:after_extract_linked_users, users, post)

    users
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
    users.each { |u| create_notification(u, Notification.types[type], post, opts) }

    users
  end

  def pm_watching_users(post)
    return [] if !post.topic.private_message?
    directly_targeted_users(post).filter do |u|
      notification_level = TopicUser.get(post.topic, u)&.notification_level
      notification_level == TopicUser.notification_levels[:watching]
    end
  end

  def notify_pm_users(post, reply_to_user, quoted_users, notified, new_record = false)
    return [] unless post.topic

    warn_if_not_sidekiq

    # To simplify things and to avoid IMAP double sync issues, and to cut down
    # on emails sent via SMTP, any topic_allowed_users (except those who are
    # not_allowed?) for a group that has SMTP enabled will have their notification
    # email combined into one and sent via a single group SMTP email with CC addresses.
    emails_to_skip_send = email_using_group_smtp_if_configured(post)

    # We create notifications for all directly_targeted_users and email those
    # who do _not_ have their email addresses in the emails_to_skip_send array
    # (which will include all topic allowed users' email addresses if group SMTP
    # is enabled).
    users = directly_targeted_users(post).reject { |u| notified.include?(u) }
    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    users.each do |user|
      if reply_to_user == user || pm_watching_users(post).include?(user) || user.staged?
        create_notification(
          user,
          Notification.types[:private_message],
          post,
          skip_send_email_to: emails_to_skip_send,
        )
      end
    end

    # Users that are part of all mentioned groups. Emails sent by this notification
    # flow will not be sent via group SMTP if it is enabled.
    users = indirectly_targeted_users(post).reject { |u| notified.include?(u) }
    DiscourseEvent.trigger(:before_create_notifications_for_users, users, post)
    users.each do |user|
      case TopicUser.get(post.topic, user)&.notification_level
      when TopicUser.notification_levels[:watching]
        create_pm_notification(user, post, emails_to_skip_send)
      when TopicUser.notification_levels[:tracking]
        # TopicUser is the canonical source of topic notification levels, except for
        # new topics created within a group with default notification level set to
        # `watching_first_post`. TopicUser notification level is set to `tracking`
        # for these.
        if is_replying?(user, reply_to_user, quoted_users) ||
             (new_record && group_watched_first_post?(user, post))
          create_pm_notification(user, post, emails_to_skip_send)
        else
          notify_group_summary(user, post.topic)
        end
      when TopicUser.notification_levels[:regular]
        if is_replying?(user, reply_to_user, quoted_users)
          create_pm_notification(user, post, emails_to_skip_send)
        end
      end
    end
  end

  def group_notifying_via_smtp(post)
    return if !SiteSetting.enable_smtp || post.post_type != Post.types[:regular]
    return if post.topic.allowed_groups.none?

    return post.topic.first_smtp_enabled_group if post.topic.allowed_groups.count == 1

    topic_incoming_email = post.topic.incoming_email.first
    return if topic_incoming_email.blank?

    group = Group.find_by_email(topic_incoming_email.to_addresses)
    return post.topic.first_smtp_enabled_group if !group&.smtp_enabled
    group
  end

  def email_using_group_smtp_if_configured(post)
    emails_to_skip_send = []
    group = group_notifying_via_smtp(post)
    return emails_to_skip_send if group.blank?

    to_address = nil
    cc_addresses = []

    # We need to use topic_allowed_users here instead of directly_targeted_users
    # because we want to make sure the to_address goes to the OP of the topic.
    topic_allowed_users_by_age =
      post
        .topic
        .topic_allowed_users
        .includes(:user)
        .order(:created_at)
        .reject { |tau| not_allowed?(tau.user, post) }
    return emails_to_skip_send if topic_allowed_users_by_age.empty?

    # This should usually be the OP of the topic, unless they are the one
    # replying by email (they are excluded by not_allowed? then)
    to_address = topic_allowed_users_by_age.first.user.email
    cc_addresses = topic_allowed_users_by_age[1..-1].map { |tau| tau.user.email }
    email_addresses = [to_address, cc_addresses].flatten

    # If any of these email addresses were cc address on the
    # incoming email for the target post, do not send them emails (they
    # already have been notified by the CC on the email)
    if post.incoming_email.present?
      cc_addresses = cc_addresses - post.incoming_email.cc_addresses_split

      # If the to address is one of the recently added CC addresses, then we
      # need to bail early, because otherwise we are sending a notification
      # email to the user who was just added by CC. In this case the OP probably
      # replied and CC'd some people, and they are the only other topic users.
      return if post.incoming_email.cc_addresses_split.include?(to_address)

      # We don't want to create an email storm if someone emails the group and
      # CC's 50 support addresses from various places, which all then respond
      # with auto-responders saying they have received our email. Any auto-generated
      # emails should not propagate notifications to anyone else, not even
      # the regular topic user notifications.
      return email_addresses.dup.uniq if post.incoming_email.is_auto_generated?
    end

    # Send a single email using group SMTP settings to cut down on the
    # number of emails sent via SMTP, also to replicate how support systems
    # and group inboxes generally work in other systems.
    #
    # We need to send this on a delay to allow for editing and finalising
    # posts, the same way we do for private_message user emails/notifications.
    Jobs.enqueue_in(
      SiteSetting.personal_email_time_window_seconds,
      :group_smtp_email,
      group_id: group.id,
      post_id: post.id,
      email: to_address,
      cc_emails: cc_addresses,
    )

    # Add the group's email_username into the array, because it is used for
    # skip_send_email_to in the case of user private message notifications
    # (we do not want the group to be sent any emails from here because it
    # will make another email for IMAP to pick up in the group's mailbox)
    emails_to_skip_send = email_addresses.dup if email_addresses.any?
    emails_to_skip_send << group.email_username
    emails_to_skip_send.uniq
  end

  def notify_post_users(
    post,
    notified,
    group_ids: nil,
    include_topic_watchers: true,
    include_category_watchers: true,
    include_tag_watchers: true,
    new_record: false,
    notification_type: nil
  )
    return [] unless post.topic

    warn_if_not_sidekiq

    condition = +<<~SQL
      users.id IN (
        SELECT id FROM users WHERE false
        /*topic*/
        /*category*/
        /*tags*/
      )
    SQL
    condition.sub! "/*topic*/", <<~SQL if include_topic_watchers
        UNION
        SELECT user_id
          FROM topic_users
         WHERE notification_level = :watching
           AND topic_id = :topic_id
      SQL

    condition.sub! "/*category*/", <<~SQL if include_category_watchers
        UNION

        SELECT cu.user_id
          FROM category_users cu
     LEFT JOIN topic_users tu ON tu.user_id = cu.user_id
                             AND tu.topic_id = :topic_id
         WHERE cu.notification_level = :watching
           AND cu.category_id = :category_id
           AND (tu.user_id IS NULL OR tu.notification_level = :watching)
      SQL

    tag_ids = post.topic.topic_tags.pluck("topic_tags.tag_id")

    condition.sub! "/*tags*/", <<~SQL if include_tag_watchers && tag_ids.present?
        UNION

        SELECT tag_users.user_id
          FROM tag_users
     LEFT JOIN topic_users tu ON tu.user_id = tag_users.user_id
                             AND tu.topic_id = :topic_id
     LEFT JOIN tag_group_memberships tgm ON tag_users.tag_id = tgm.tag_id
     LEFT JOIN tag_group_permissions tgp ON tgm.tag_group_id = tgp.tag_group_id
     LEFT JOIN group_users gu ON gu.user_id = tag_users.user_id
         WHERE (
            tgp.group_id IS NULL OR
            tgp.group_id = gu.group_id OR
            tgp.group_id = :everyone_group_id OR
            gu.group_id = :staff_group_id
          )
               AND (tag_users.notification_level = :watching
                    AND tag_users.tag_id IN (:tag_ids)
                    AND (tu.user_id IS NULL OR tu.notification_level = :watching))
      SQL

    notify =
      User.where(
        condition,
        watching: TopicUser.notification_levels[:watching],
        topic_id: post.topic_id,
        category_id: post.topic.category_id,
        tag_ids: tag_ids,
        staff_group_id: Group::AUTO_GROUPS[:staff],
        everyone_group_id: Group::AUTO_GROUPS[:everyone],
      )

    if group_ids.present?
      notify = notify.joins(:group_users).where("group_users.group_id IN (?)", group_ids)
    end

    notify = notify.where(staged: false).staff if post.topic.private_message?

    exclude_user_ids = notified.map(&:id)
    notify = notify.where("users.id NOT IN (?)", exclude_user_ids) if exclude_user_ids.present?

    DiscourseEvent.trigger(:before_create_notifications_for_users, notify, post)

    already_seen_user_ids =
      Set.new(
        TopicUser
          .where(topic_id: post.topic.id)
          .where("last_read_post_number >= ?", post.post_number)
          .pluck(:user_id),
      )

    each_user_in_batches(notify) do |user|
      calculated_type =
        if !new_record && already_seen_user_ids.include?(user.id)
          Notification.types[:edited]
        elsif notification_type
          Notification.types[notification_type]
        else
          Notification.types[:posted]
        end
      opts = {}
      opts[:display_username] = post.last_editor.username if calculated_type ==
        Notification.types[:edited]
      create_notification(user, calculated_type, post, opts)
    end

    notify
  end

  def warn_if_not_sidekiq
    unless Sidekiq.server?
      Rails.logger.warn(
        "PostAlerter.#{caller_locations(1, 1)[0].label} was called outside of sidekiq",
      )
    end
  end

  private

  def each_user_in_batches(users)
    # This is race-condition-safe, unlike #find_in_batches
    users
      .pluck(:id)
      .each_slice(USER_BATCH_SIZE) do |user_ids_batch|
        User.where(id: user_ids_batch).includes(:do_not_disturb_timings).each { |user| yield(user) }
      end
  end

  def create_pm_notification(user, post, emails_to_skip_send)
    create_notification(
      user,
      Notification.types[:private_message],
      post,
      skip_send_email_to: emails_to_skip_send,
    )
  end

  def is_replying?(user, reply_to_user, quoted_users)
    reply_to_user == user || quoted_users.include?(user)
  end

  def user_watching_topic?(user, topic)
    TopicUser.exists?(
      user_id: user.id,
      topic_id: topic.id,
      notification_level: TopicUser.notification_levels[:watching],
    )
  end

  def group_watched_first_post?(user, post)
    post.is_first_post? && group_watchers(post.topic).include?(user.id)
  end
end
