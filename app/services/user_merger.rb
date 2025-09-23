# frozen_string_literal: true

class UserMerger
  def initialize(source_user, target_user, acting_user = nil)
    @source_user = source_user
    @target_user = target_user
    @acting_user = acting_user
    @user_id = source_user.id
    @source_primary_email = source_user.email
  end

  def merge!
    update_username
    move_posts
    update_user_ids
    merge_given_daily_likes
    merge_post_timings
    merge_user_visits
    update_site_settings
    merge_user_attributes
    merge_user_associated_accounts

    DiscourseEvent.trigger(:merging_users, @source_user, @target_user)
    update_user_stats

    delete_source_user
    log_merge

    @target_user.reload
  end

  protected

  def update_username
    return if @source_user.username == @target_user.username

    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.updating_username") },
                           user_ids: [@acting_user.id]
    end
    UsernameChanger.update_username(
      user_id: @source_user.id,
      old_username: @source_user.username,
      new_username: @target_user.username,
      avatar_template: @target_user.avatar_template,
      asynchronous: false,
    )
  end

  def move_posts
    posts =
      Post
        .with_deleted
        .where(user_id: @source_user.id)
        .order(:topic_id, :post_number)
        .pluck(:topic_id, :id)

    return if posts.count == 0

    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.changing_post_ownership") },
                           user_ids: [@acting_user.id]
    end

    last_topic_id = nil
    post_ids = []

    posts.each do |current_topic_id, current_post_id|
      if last_topic_id != current_topic_id && post_ids.any?
        change_post_owner(last_topic_id, post_ids)
        post_ids = []
      end

      last_topic_id = current_topic_id
      post_ids << current_post_id
    end

    change_post_owner(last_topic_id, post_ids) if post_ids.any?
  end

  def change_post_owner(topic_id, post_ids)
    PostOwnerChanger.new(
      topic_id: topic_id,
      post_ids: post_ids,
      new_owner: @target_user,
      acting_user: Discourse.system_user,
      skip_revision: true,
    ).change_owner!
  end

  def merge_given_daily_likes
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.merging_given_daily_likes") },
                           user_ids: [@acting_user.id]
    end

    sql = <<~SQL
      INSERT INTO given_daily_likes AS g (user_id, likes_given, given_date, limit_reached)
        SELECT
          :target_user_id                AS user_id,
          COUNT(1)                       AS likes_given,
          a.created_at::DATE             AS given_date,
          COUNT(1) >= :max_likes_per_day AS limit_reached
        FROM post_actions AS a
        WHERE a.user_id = :target_user_id
              AND a.deleted_at IS NULL
              AND EXISTS(
                  SELECT 1
                  FROM given_daily_likes AS g
                  WHERE g.user_id = :source_user_id AND a.created_at::DATE = g.given_date
              )
        GROUP BY given_date
      ON CONFLICT (user_id, given_date)
        DO UPDATE
          SET likes_given = EXCLUDED.likes_given,
            limit_reached = EXCLUDED.limit_reached
    SQL

    DB.exec(
      sql,
      source_user_id: @source_user.id,
      target_user_id: @target_user.id,
      max_likes_per_day: SiteSetting.max_likes_per_day,
      action_type_id: PostActionType.types[:like],
    )
  end

  def merge_post_timings
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.merging_post_timings") },
                           user_ids: [@acting_user.id]
    end

    update_user_id(
      :post_timings,
      conditions: ["x.topic_id = y.topic_id", "x.post_number = y.post_number"],
    )
    sql = <<~SQL
      UPDATE post_timings AS t
      SET msecs = LEAST(t.msecs::bigint + s.msecs, 2^31 - 1)
      FROM post_timings AS s
      WHERE t.user_id = :target_user_id AND s.user_id = :source_user_id
            AND t.topic_id = s.topic_id AND t.post_number = s.post_number
    SQL

    DB.exec(sql, source_user_id: @source_user.id, target_user_id: @target_user.id)
  end

  def merge_user_visits
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.merging_user_visits") },
                           user_ids: [@acting_user.id]
    end

    update_user_id(:user_visits, conditions: "x.visited_at = y.visited_at")

    sql = <<~SQL
      UPDATE user_visits AS t
      SET posts_read = t.posts_read + s.posts_read,
        mobile       = t.mobile OR s.mobile,
        time_read    = t.time_read + s.time_read
      FROM user_visits AS s
      WHERE t.user_id = :target_user_id AND s.user_id = :source_user_id
            AND t.visited_at = s.visited_at
    SQL

    DB.exec(sql, source_user_id: @source_user.id, target_user_id: @target_user.id)
  end

  def update_site_settings
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.updating_site_settings") },
                           user_ids: [@acting_user.id]
    end

    SiteSetting
      .all_settings(include_hidden: true)
      .each do |setting|
        if setting[:type] == "username" && setting[:value] == @source_user.username
          SiteSetting.set_and_log(setting[:setting], @target_user.username)
        end
      end
  end

  def update_user_stats
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.updating_user_stats") },
                           user_ids: [@acting_user.id]
    end

    # topics_entered
    DB.exec(<<~SQL, target_user_id: @target_user.id)
      UPDATE user_stats
      SET topics_entered = (
        SELECT COUNT(topic_id)
        FROM topic_views
        WHERE user_id = :target_user_id
      )
      WHERE user_id = :target_user_id
    SQL

    # time_read and days_visited
    DB.exec(<<~SQL, target_user_id: @target_user.id)
      UPDATE user_stats
      SET time_read  = COALESCE(x.time_read, 0),
        days_visited = COALESCE(x.days_visited, 0)
      FROM (
             SELECT
               SUM(time_read) AS time_read,
               COUNT(1)       AS days_visited
             FROM user_visits
             WHERE user_id = :target_user_id
           ) AS x
      WHERE user_id = :target_user_id
    SQL

    # posts_read_count
    DB.exec(<<~SQL, target_user_id: @target_user.id)
      UPDATE user_stats
      SET posts_read_count = (
        SELECT COUNT(1)
        FROM post_timings AS pt
        WHERE pt.user_id = :target_user_id AND EXISTS(
            SELECT 1
            FROM topics AS t
            WHERE t.archetype = 'regular' AND t.deleted_at IS NULL
        ))
      WHERE user_id = :target_user_id
    SQL

    # likes_given, likes_received, new_since, read_faq, first_post_created_at
    DB.exec(<<~SQL, source_user_id: @source_user.id, target_user_id: @target_user.id)
      UPDATE user_stats AS t
      SET likes_given         = t.likes_given + s.likes_given,
        likes_received        = t.likes_received + s.likes_received,
        new_since             = LEAST(t.new_since, s.new_since),
        read_faq              = LEAST(t.read_faq, s.read_faq),
        first_post_created_at = LEAST(t.first_post_created_at, s.first_post_created_at)
      FROM user_stats AS s
      WHERE t.user_id = :target_user_id AND s.user_id = :source_user_id
    SQL
  end

  def merge_user_attributes
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.merging_user_attributes") },
                           user_ids: [@acting_user.id]
    end

    DB.exec(<<~SQL, source_user_id: @source_user.id, target_user_id: @target_user.id)
      UPDATE users AS t
      SET created_at              = LEAST(t.created_at, s.created_at),
        updated_at                = LEAST(t.updated_at, s.updated_at),
        seen_notification_id      = GREATEST(t.seen_notification_id, s.seen_notification_id),
        last_posted_at            = GREATEST(t.last_seen_at, s.last_seen_at),
        last_seen_at              = GREATEST(t.last_seen_at, s.last_seen_at),
        admin                     = t.admin OR s.admin,
        last_emailed_at           = GREATEST(t.last_emailed_at, s.last_emailed_at),
        trust_level               = GREATEST(t.trust_level, s.trust_level),
        previous_visit_at         = GREATEST(t.previous_visit_at, s.previous_visit_at),
        date_of_birth             = COALESCE(t.date_of_birth, s.date_of_birth),
        ip_address                = COALESCE(t.ip_address, s.ip_address),
        moderator                 = t.moderator OR s.moderator,
        title                     = COALESCE(t.title, s.title),
        primary_group_id          = COALESCE(t.primary_group_id, s.primary_group_id),
        registration_ip_address   = COALESCE(t.registration_ip_address, s.registration_ip_address),
        first_seen_at             = LEAST(t.first_seen_at, s.first_seen_at),
        manual_locked_trust_level = GREATEST(t.manual_locked_trust_level, s.manual_locked_trust_level)
      FROM users AS s
      WHERE t.id = :target_user_id AND s.id = :source_user_id
    SQL

    DB.exec(<<~SQL, source_user_id: @source_user.id, target_user_id: @target_user.id)
      UPDATE user_profiles AS t
      SET location           = COALESCE(t.location, s.location),
        website              = COALESCE(t.website, s.website),
        bio_raw              = COALESCE(t.bio_raw, s.bio_raw),
        bio_cooked           = COALESCE(t.bio_cooked, s.bio_cooked),
        bio_cooked_version   = COALESCE(t.bio_cooked_version, s.bio_cooked_version),
        profile_background_upload_id = COALESCE(t.profile_background_upload_id, s.profile_background_upload_id),
        dismissed_banner_key = COALESCE(t.dismissed_banner_key, s.dismissed_banner_key),
        granted_title_badge_id = COALESCE(t.granted_title_badge_id, s.granted_title_badge_id),
        card_background_upload_id = COALESCE(t.card_background_upload_id, s.card_background_upload_id),
        views                = t.views + s.views
      FROM user_profiles AS s
      WHERE t.user_id = :target_user_id AND s.user_id = :source_user_id
    SQL
  end

  def merge_user_associated_accounts
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           {
                             message:
                               I18n.t("admin.user.merge_user.merging_user_associated_accounts"),
                           },
                           user_ids: [@acting_user.id]
    end

    UserAssociatedAccount.where(user_id: @source_user.id).update_all(<<~SQL)
      user_id = CASE
        WHEN EXISTS (
          SELECT 1
          FROM user_associated_accounts AS conflicts
          WHERE (conflicts.user_id = #{@target_user.id} AND conflicts.provider_name = user_associated_accounts.provider_name)
        )
        THEN NULL
        ELSE #{@target_user.id}
      END
    SQL
  end

  def update_user_ids
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.updating_user_ids") },
                           user_ids: [@acting_user.id]
    end

    Category.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    update_user_id(:category_users, conditions: ["x.category_id = y.category_id"])

    update_user_id(:developers)

    update_user_id(:draft_sequences, conditions: "x.draft_key = y.draft_key")
    update_user_id(:drafts, conditions: "x.draft_key = y.draft_key")

    update_user_id(:dismissed_topic_users, conditions: "x.topic_id = y.topic_id")

    EmailLog.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    GroupHistory.where(acting_user_id: @source_user.id).update_all(acting_user_id: @target_user.id)
    GroupHistory.where(target_user_id: @source_user.id).update_all(target_user_id: @target_user.id)

    update_user_id(:group_users, conditions: "x.group_id = y.group_id")

    IncomingEmail.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    IncomingLink.where(user_id: @source_user.id).update_all(user_id: @target_user.id)
    IncomingLink.where(current_user_id: @source_user.id).update_all(
      current_user_id: @target_user.id,
    )

    InvitedUser.where(user_id: @source_user.id).update_all(user_id: @target_user.id)
    Invite
      .with_deleted
      .where(invited_by_id: @source_user.id)
      .update_all(invited_by_id: @target_user.id)
    Invite
      .with_deleted
      .where(deleted_by_id: @source_user.id)
      .update_all(deleted_by_id: @target_user.id)

    update_user_id(:muted_users, conditions: "x.muted_user_id = y.muted_user_id")
    update_user_id(
      :muted_users,
      user_id_column_name: "muted_user_id",
      conditions: "x.user_id = y.user_id",
    )

    update_user_id(:ignored_users, conditions: "x.ignored_user_id = y.ignored_user_id")
    update_user_id(
      :ignored_users,
      user_id_column_name: "ignored_user_id",
      conditions: "x.user_id = y.user_id",
    )

    Notification.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    update_user_id(
      :post_actions,
      conditions: [
        "x.post_id = y.post_id",
        "x.post_action_type_id = y.post_action_type_id",
        "x.targets_topic = y.targets_topic",
      ],
    )

    PostAction.where(deleted_by_id: @source_user.id).update_all(deleted_by_id: @target_user.id)
    PostAction.where(deferred_by_id: @source_user.id).update_all(deferred_by_id: @target_user.id)
    PostAction.where(agreed_by_id: @source_user.id).update_all(agreed_by_id: @target_user.id)
    PostAction.where(disagreed_by_id: @source_user.id).update_all(disagreed_by_id: @target_user.id)

    PostRevision.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    Post
      .with_deleted
      .where(deleted_by_id: @source_user.id)
      .update_all(deleted_by_id: @target_user.id)
    Post
      .with_deleted
      .where(last_editor_id: @source_user.id)
      .update_all(last_editor_id: @target_user.id)
    Post.with_deleted.where(locked_by_id: @source_user.id).update_all(locked_by_id: @target_user.id)
    Post
      .with_deleted
      .where(reply_to_user_id: @source_user.id)
      .update_all(reply_to_user_id: @target_user.id)

    Reviewable.where(created_by_id: @source_user.id).update_all(created_by_id: @target_user.id)
    ReviewableHistory.where(created_by_id: @source_user.id).update_all(
      created_by_id: @target_user.id,
    )

    SearchLog.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    update_user_id(:tag_users, conditions: "x.tag_id = y.tag_id")

    Theme.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    update_user_id(:topic_allowed_users, conditions: "x.topic_id = y.topic_id")

    TopicEmbed
      .with_deleted
      .where(deleted_by_id: @source_user.id)
      .update_all(deleted_by_id: @target_user.id)

    TopicLink.where(user_id: @source_user.id).update_all(user_id: @target_user.id)
    TopicLinkClick.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    TopicTimer
      .with_deleted
      .where(deleted_by_id: @source_user.id)
      .update_all(deleted_by_id: @target_user.id)

    update_user_id(
      :topic_timers,
      conditions: [
        "x.status_type = y.status_type",
        "x.timerable_id = y.timerable_id",
        "y.deleted_at IS NULL",
      ],
    )

    update_user_id(:topic_users, conditions: "x.topic_id = y.topic_id")

    update_user_id(:topic_views, conditions: "x.topic_id = y.topic_id")

    Topic
      .with_deleted
      .where(deleted_by_id: @source_user.id)
      .update_all(deleted_by_id: @target_user.id)

    UnsubscribeKey.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    Upload.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    update_user_id(:user_archived_messages, conditions: "x.topic_id = y.topic_id")

    update_user_id(
      :user_actions,
      user_id_column_name: "user_id",
      conditions: [
        "x.action_type = y.action_type",
        "x.target_topic_id IS NOT DISTINCT FROM y.target_topic_id",
        "x.target_post_id IS NOT DISTINCT FROM y.target_post_id",
        "(x.acting_user_id IN (:source_user_id, :target_user_id) OR x.acting_user_id IS NOT DISTINCT FROM y.acting_user_id)",
      ],
    )
    update_user_id(
      :user_actions,
      user_id_column_name: "acting_user_id",
      conditions: [
        "x.action_type = y.action_type",
        "x.user_id = y.user_id",
        "x.target_topic_id IS NOT DISTINCT FROM y.target_topic_id",
        "x.target_post_id IS NOT DISTINCT FROM y.target_post_id",
      ],
    )

    update_user_id(
      :user_badges,
      conditions: [
        "x.badge_id = y.badge_id",
        "x.seq = y.seq",
        "x.post_id IS NOT DISTINCT FROM y.post_id",
      ],
    )

    update_user_id(
      :bookmarks,
      conditions: [
        "x.bookmarkable_type = y.bookmarkable_type",
        "x.bookmarkable_id = y.bookmarkable_id",
      ],
    )

    UserBadge.where(granted_by_id: @source_user.id).update_all(granted_by_id: @target_user.id)

    update_user_id(:user_custom_fields, conditions: "x.name = y.name")

    if @target_user.human?
      update_user_id(
        :user_emails,
        conditions: "x.email = y.email OR y.primary = false",
        updates: '"primary" = false',
      )
    end

    UserExport.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    UserHistory.where(target_user_id: @source_user.id).update_all(target_user_id: @target_user.id)
    UserHistory.where(acting_user_id: @source_user.id).update_all(acting_user_id: @target_user.id)

    UserProfileView.where(user_profile_id: @source_user.id).update_all(
      user_profile_id: @target_user.id,
    )
    UserProfileView.where(user_id: @source_user.id).update_all(user_id: @target_user.id)

    UserWarning.where(user_id: @source_user.id).update_all(user_id: @target_user.id)
    UserWarning.where(created_by_id: @source_user.id).update_all(created_by_id: @target_user.id)

    User.where(approved_by_id: @source_user.id).update_all(approved_by_id: @target_user.id)
  end

  def delete_source_user
    if @acting_user
      ::MessageBus.publish "/merge_user",
                           { message: I18n.t("admin.user.merge_user.deleting_source_user") },
                           user_ids: [@acting_user.id]
    end

    @source_user.reload

    @source_user.skip_email_validation = true
    @source_user.update(
      admin: false,
      email: "#{@source_user.username}_#{SecureRandom.hex}@no-email.invalid",
    )

    UserDestroyer.new(Discourse.system_user).destroy(@source_user, quiet: true)
  end

  def log_merge
    logger = StaffActionLogger.new(@acting_user || Discourse.system_user)
    logger.log_user_merge(@target_user, @source_user.username, @source_primary_email || "")
  end

  def update_user_id(table_name, opts = {})
    builder = update_user_id_sql_builder(table_name, opts)
    builder.exec(source_user_id: @source_user.id, target_user_id: @target_user.id)
  end

  def update_user_id_sql_builder(table_name, opts = {})
    user_id_column_name = opts[:user_id_column_name] || :user_id
    conditions = Array.wrap(opts[:conditions])
    updates = Array.wrap(opts[:updates])

    builder = DB.build(<<~SQL)
      UPDATE #{table_name} AS x
      /*set*/
      WHERE x.#{user_id_column_name} = :source_user_id AND NOT EXISTS(
          SELECT 1
          FROM #{table_name} AS y
          /*where*/
      )
    SQL

    builder.set("#{user_id_column_name} = :target_user_id")
    updates.each { |u| builder.set(u) }

    builder.where("y.#{user_id_column_name} = :target_user_id")
    conditions.each { |c| builder.where(c) }

    builder
  end
end
