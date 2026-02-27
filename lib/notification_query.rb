# frozen_string_literal: true

class NotificationQuery
  attr_reader :user, :guardian

  # Cap unread notification queries to avoid full table scans
  MAX_UNREAD_NOTIFICATIONS = 99
  MAX_UNREAD_BACKLOG = 400

  def initialize(user:, guardian: nil)
    @user = user
    @guardian = guardian || Guardian.new(user)
  end

  # Returns notifications with access control in SQL (via base_scope) plus post-fetch
  # filtering for disabled badges and edge cases not covered by the lightweight SQL checks.
  def list(limit: 30, offset: 0, types: nil, filter: nil, order: :desc, prioritized: false)
    scope = base_scope
    scope = scope.where(notification_type: types) if types.present?
    scope = apply_read_filter(scope, filter)

    if prioritized
      if types.blank?
        scope = exclude_likes_if_disabled(scope)
        scope = with_priority_ordering(scope, deprioritize: Notification.like_types)
      else
        scope = with_priority_ordering(scope, deprioritize: [])
      end
    else
      scope = scope.order(created_at: order)
    end

    notifications = scope.includes(:topic).offset(offset).limit(limit).to_a
    filter_inaccessible(notifications)
  end

  # Single raw SQL query that computes all count variants in one pass.
  def bulk_counts
    @bulk_counts ||= compute_bulk_counts
  end

  def total_count(filter: nil)
    scope = base_scope
    scope = apply_read_filter(scope, filter)
    scope.count
  end

  def unread_count_for_type(notification_type, since: nil)
    sql = <<~SQL
      SELECT COUNT(*)
        FROM notifications n
   LEFT JOIN topics t ON t.id = n.topic_id
   LEFT JOIN categories c ON c.id = t.category_id
       WHERE n.user_id = :user_id
         AND NOT n.read
         AND n.notification_type = :notification_type
         AND #{topic_visibility_sql}
         #{access_control_sql}
         #{since ? "AND n.created_at > :since" : ""}
    SQL

    DB.query_single(sql, access_control_params.merge(notification_type:, since:))[0].to_i
  end

  def max_id(since_id: nil)
    scope = base_scope
    scope = scope.where("notifications.id > ?", since_id) if since_id
    scope.maximum(:id)
  end

  def recent_ids_with_read_status(limit: 20)
    visibility = topic_visibility_sql
    acl = access_control_sql

    sql = <<~SQL
      SELECT * FROM (
        SELECT n.id, n.read FROM notifications n
        LEFT JOIN topics t ON n.topic_id = t.id
        LEFT JOIN categories c ON c.id = t.category_id
        WHERE #{visibility}
          #{acl}
          AND n.high_priority AND NOT n.read
          AND n.user_id = :user_id
        ORDER BY n.id DESC
        LIMIT :limit
      ) AS x
      UNION ALL
      SELECT * FROM (
        SELECT n.id, n.read FROM notifications n
        LEFT JOIN topics t ON n.topic_id = t.id
        LEFT JOIN categories c ON c.id = t.category_id
        WHERE #{visibility}
          #{acl}
          AND (NOT n.high_priority OR n.read)
          AND n.user_id = :user_id
        ORDER BY n.id DESC
        LIMIT :limit
      ) AS y
    SQL

    DB.query(sql, access_control_params.merge(limit:)).map! { |r| [r.id, r.read] }
  end

  private

  def compute_bulk_counts
    rows = DB.query(<<~SQL, access_control_params.merge(limit: MAX_UNREAD_BACKLOG))
      SELECT n.id, n.high_priority, n.notification_type
        FROM notifications n
   LEFT JOIN topics t ON t.id = n.topic_id
   LEFT JOIN categories c ON c.id = t.category_id
       WHERE n.user_id = :user_id
         AND NOT n.read
         AND #{topic_visibility_sql}
         #{access_control_sql}
       LIMIT :limit
    SQL

    seen_id = @user.seen_notification_id || 0
    counts = { unread: 0, high: 0, low: 0, pm: 0 }
    grouped = Hash.new(0)
    pm_type = Notification.types[:private_message]

    rows.each do |row|
      grouped[row.notification_type] += 1
      counts[:high] += 1 if row.high_priority

      if row.id > seen_id
        counts[:unread] += 1
        counts[:low] += 1 unless row.high_priority
        counts[:pm] += 1 if row.notification_type == pm_type
      end
    end

    # Subtract disabled badge notifications from counts
    badge_type = Notification.types[:granted_badge]
    badge_count = grouped[badge_type] || 0
    if badge_count > 0 && !SiteSetting.enable_badges
      grouped.delete(badge_type)
      counts[:unread] -= badge_count
      counts[:low] -= badge_count
    end

    {
      unread_count: [counts[:unread], MAX_UNREAD_NOTIFICATIONS].min,
      unread_high_priority_count: [counts[:high], MAX_UNREAD_NOTIFICATIONS].min,
      unread_low_priority_count: [counts[:low], MAX_UNREAD_NOTIFICATIONS].min,
      new_personal_messages_count: counts[:pm],
      grouped_unread_counts: grouped,
    }
  end

  # SQL fragment for topic visibility, shared between AR scope and raw SQL.
  # Staff can see soft-deleted topics; regular users cannot.
  # Hard-deleted topics (LEFT JOIN gives NULL) are always excluded via topics.id IS NOT NULL.
  def topic_visibility_sql
    if @guardian.is_staff?
      "(n.topic_id IS NULL OR t.id IS NOT NULL)"
    else
      "(n.topic_id IS NULL OR t.deleted_at IS NULL)"
    end
  end

  def skip_access_control?
    @guardian.is_admin? && !SiteSetting.suppress_secured_categories_from_admin
  end

  def secure_category_ids_for_query
    @secure_category_ids_for_query ||=
      begin
        ids = @user.secure_category_ids
        ids.empty? ? [-1] : ids
      end
  end

  # SQL fragment for access control — checks category permissions, PM membership,
  # and shared draft visibility. Parameterized by table aliases to work in both
  # raw SQL (n/t/c) and ActiveRecord scope (notifications/topics/categories) contexts.
  #
  # For raw SQL: returns "AND (...)" prefix
  # For AR scope: returns bare condition (no AND prefix)
  def access_control_sql(notifications: "n", topics: "t", categories: "c", prefix: true)
    return "" if skip_access_control?

    shared_draft_sql =
      if SiteSetting.shared_drafts_enabled? && !@guardian.can_see_shared_draft?
        "AND NOT EXISTS (SELECT 1 FROM shared_drafts sd WHERE sd.topic_id = #{topics}.id)"
      else
        ""
      end

    condition = <<~SQL.squish
      (
        #{notifications}.topic_id IS NULL
        OR (
          CASE #{topics}.archetype
          WHEN 'private_message' THEN (
            #{topics}.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = :user_id)
            OR #{topics}.id IN (
              SELECT tg.topic_id FROM topic_allowed_groups tg
              JOIN group_users gu ON gu.group_id = tg.group_id AND gu.user_id = :user_id
            )
          )
          ELSE (
            #{categories}.id IS NULL
            OR NOT #{categories}.read_restricted
            OR #{categories}.id IN (:secure_category_ids)
          )
          END
          #{shared_draft_sql}
        )
      )
    SQL

    prefix ? "AND #{condition}" : condition
  end

  def access_control_params
    { user_id: @user.id, secure_category_ids: secure_category_ids_for_query }
  end

  def base_scope
    scope =
      Notification
        .where(user: @user)
        .joins("LEFT JOIN topics ON topics.id = notifications.topic_id")
        .joins("LEFT JOIN categories ON categories.id = topics.category_id")
        .where(
          if @guardian.is_staff?
            "notifications.topic_id IS NULL OR topics.id IS NOT NULL"
          else
            "notifications.topic_id IS NULL OR topics.deleted_at IS NULL"
          end,
        )

    unless skip_access_control?
      scope =
        scope.where(
          access_control_sql(
            notifications: "notifications",
            topics: "topics",
            categories: "categories",
            prefix: false,
          ),
          user_id: @user.id,
          secure_category_ids: secure_category_ids_for_query,
        )
    end

    scope
  end

  # Post-fetch filtering: one canonical method applied to every list result.
  # Ensures display is always consistent regardless of which code path fetches.
  def filter_inaccessible(notifications)
    return notifications if notifications.empty?

    notifications = filter_inaccessible_topics(notifications)
    notifications = filter_disabled_badges(notifications)
    notifications
  end

  def filter_inaccessible_topics(notifications)
    topic_ids = notifications.filter_map(&:topic_id).uniq
    return notifications if topic_ids.empty?

    accessible_topic_ids = @guardian.can_see_topic_ids(topic_ids:).to_set
    notifications.select { |n| n.topic_id.blank? || accessible_topic_ids.include?(n.topic_id) }
  end

  def filter_disabled_badges(notifications)
    badge_type = Notification.types[:granted_badge]
    badge_notifications = notifications.select { |n| n.notification_type == badge_type }
    return notifications if badge_notifications.empty?

    unless SiteSetting.enable_badges
      return notifications.reject { |n| n.notification_type == badge_type }
    end

    badge_ids = badge_notifications.filter_map { |n| n.data_hash[:badge_id] }
    return notifications if badge_ids.empty?

    enabled_badge_ids = Badge.where(id: badge_ids, enabled: true).pluck(:id).to_set
    notifications.reject do |n|
      n.notification_type == badge_type && !enabled_badge_ids.include?(n.data_hash[:badge_id])
    end
  end

  def apply_read_filter(scope, filter)
    case filter.to_s
    when "read"
      scope.where(read: true)
    when "unread"
      scope.where(read: false)
    else
      scope
    end
  end

  def exclude_likes_if_disabled(scope)
    if @user.user_option&.like_notification_frequency ==
         UserOption.like_notification_frequency_type[:never]
      scope.where.not(notification_type: Notification.like_types)
    else
      scope
    end
  end

  def with_priority_ordering(scope, deprioritize: [])
    scope
      .order(Arel.sql("(notifications.high_priority AND NOT notifications.read) DESC"))
      .order(unread_ordering_sql(deprioritize))
      .order(Arel.sql("notifications.created_at DESC"))
  end

  def unread_ordering_sql(deprioritized_types)
    if deprioritized_types.present?
      DB.sql_fragment(
        "NOT notifications.read AND notifications.notification_type NOT IN (?) DESC",
        deprioritized_types,
      )
    else
      Arel.sql("NOT notifications.read DESC")
    end
  end
end
