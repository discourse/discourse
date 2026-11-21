# frozen_string_literal: true

class Notification::Feed
  MAX_COUNTED = 400
  OPTIMIZATION_FENCE = 0
  MAX_ID_DIGITS = 18
  READ_STATES = { read: true, unread: false }.freeze

  Page = Data.define(:notifications, :cursor)

  def self.data_id(key)
    "substring(notifications.data::jsonb->>'#{key}' FROM '^[0-9]{1,#{MAX_ID_DIGITS}}$')::bigint"
  end

  def self.exists(relation)
    "EXISTS (#{relation.select("1").offset(OPTIMIZATION_FENCE).to_sql})"
  end

  class Counts
    def initialize(rows)
      @rows = rows
      @unread = rows.reject(&:read)
    end

    def types
      return if full?

      @rows.map(&:notification_type).uniq
    end

    def newest_id
      @rows.map(&:newest_id).max
    end

    def grouped
      @unread.group_by(&:notification_type).transform_values { |rows| rows.sum(&:count) }
    end

    def high_priority
      sum(&:high_priority)
    end

    def unseen(except_type: nil)
      [
        sum { |row| row.unseen && row.notification_type != except_type },
        User.max_unread_notifications,
      ].min
    end

    def unseen_low_priority
      [sum { |row| row.unseen && !row.high_priority }, User.max_unread_notifications].min
    end

    def unseen_of_type(type)
      sum { |row| row.unseen && row.notification_type == type }
    end

    private

    def sum
      @unread.sum { |row| yield(row) ? row.count : 0 }
    end

    def full?
      @rows
        .partition { |row| row.high_priority && !row.read }
        .any? { |window| window.sum(&:count) >= MAX_COUNTED }
    end
  end

  def initialize(user, viewer: nil)
    @user = user
    @guardians = [user.guardian]
    @guardians << viewer if viewer && viewer.user&.id != user.id
  end

  def notifications(types: nil, state: nil)
    list = Notification.where(user_id: @user.id).where(visible)
    list = list.where(notification_type: types) if types.present?
    list = list.where(read: READ_STATES.fetch(state)) if state

    list
  end

  def menu(limit:, types: nil, state: nil)
    list = notifications(types:, state:).includes(:topic).limit(limit)
    return list.prioritized.to_a if types.present?

    list.prioritized(Notification.like_types).to_a
  end

  def page(limit:, before: nil, state: nil, types: nil)
    list = notifications(types:, state:).includes(:topic).order(created_at: :desc, id: :desc)
    list = list.where("(notifications.created_at, notifications.id) < (?, ?)", *before) if before
    list = yield(list) if block_given?

    rows = list.limit(limit + 1).to_a
    last = rows[limit - 1] if limit.positive? && rows.size > limit

    Page.new(rows.first(limit), last && [last.created_at, last.id])
  end

  def counts
    @counts ||= Counts.new(counted_rows)
  end

  def types
    @types ||= counts.types || every_type
  end

  private

  delegate :exists, :data_id, to: :class, private: true

  def every_type
    by_type =
      Notification
        .where(user_id: @user.id)
        .group(:notification_type)
        .select("notification_type, ARRAY_AGG(id) AS ids")
    visible_of_type = Notification.where("notifications.id = ANY (types.ids)").where(visible)

    DB.query_single(<<~SQL)
      SELECT types.notification_type
      FROM (#{by_type.to_sql}) types
      WHERE #{exists(visible_of_type)}
    SQL
  end

  def counted_rows
    return [] if !Notification.exists?(user_id: @user.id)

    window =
      notifications
        .where(
          "(notifications.high_priority AND NOT notifications.read) = windows.unread_high_priority",
        )
        .prioritized
        .limit(MAX_COUNTED)

    DB.query(<<~SQL)
      SELECT notification_type, high_priority, read, id > #{@user.seen_notification_id.to_i} AS unseen,
             COUNT(*) AS count, MAX(id) AS newest_id
      FROM (VALUES (TRUE), (FALSE)) windows (unread_high_priority)
      CROSS JOIN LATERAL (#{window.to_sql}) visible
      GROUP BY 1, 2, 3, 4
    SQL
  end

  def visible
    @visible ||= [
      *@guardians.flat_map { |guardian| [visible_topic(guardian), visible_reviewable(guardian)] },
      *registered_rules,
      visible_badge,
      visible_like,
    ].compact.join(" AND ")
  end

  def visible_topic(guardian)
    topics =
      guardian.visible_topic_scope(
        Topic.unscoped.where("topics.id = notifications.topic_id").where(deleted_at: nil),
      )

    posts =
      Post.unscoped.where(
        "posts.topic_id = topics.id AND posts.post_number = notifications.post_number",
      )
    covered_posts = Post.unscoped.where(<<~SQL)
      posts.topic_id = topics.id
      AND posts.post_number > notifications.post_number
      AND posts.id <= #{data_id("original_post_id")}
    SQL
    visible_posts = guardian.filter_visible_posts_without_topic_check(posts)
    visible_covered_posts = guardian.filter_visible_posts_without_topic_check(covered_posts)
    topics = topics.where(<<~SQL)
      notifications.post_number IS NULL
      OR #{exists(visible_posts)}
      OR NOT #{exists(posts)}
      OR (
        notifications.notification_type IN (#{PostAlerter::COLLAPSED_NOTIFICATION_TYPES.join(", ")})
        AND #{exists(visible_covered_posts)}
      )
    SQL

    "(notifications.topic_id IS NULL OR #{exists(topics)})"
  end

  def visible_reviewable(guardian)
    reviewable =
      if guardian.can_see_review_queue?
        reviewables =
          Reviewable
            .viewable_by(guardian.user, preload: false)
            .reorder(nil)
            .where("reviewables.id = #{data_id("reviewable_id")}")

        exists(reviewables)
      else
        "FALSE"
      end

    unless_type(
      :mentioned,
      "NULLIF(notifications.data::jsonb->>'reviewable_id', '') IS NULL OR #{reviewable}",
    )
  end

  def visible_badge
    badge =
      if SiteSetting.enable_badges
        "#{data_id("badge_id")} IN (#{Badge.enabled.select(:id).to_sql})"
      else
        "FALSE"
      end

    unless_type(:granted_badge, badge)
  end

  def registered_rules
    DiscoursePluginRegistry.notification_visibility_rules.flat_map do |registered|
      registered => { plugin:, types:, rule: }
      next [unless_type(types, "FALSE")] if !plugin.enabled?

      @guardians.map { |guardian| unless_type(types, rule.call(guardian).presence || "FALSE") }
    end
  end

  def visible_like
    return if !@user.user_option&.likes_notifications_disabled?

    "notifications.notification_type NOT IN (#{Notification.like_types.join(", ")})"
  end

  def unless_type(types, condition)
    types = Notification.types.values_at(*types).join(", ")

    "(notifications.notification_type NOT IN (#{types}) OR #{condition})"
  end
end
