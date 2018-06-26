require_dependency 'notification_levels'

class TopicUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic

  # used for serialization
  attr_accessor :post_action_data

  scope :tracking, lambda { |topic_id|
    where(topic_id: topic_id)
      .where("COALESCE(topic_users.notification_level, :regular) >= :tracking",
     regular: TopicUser.notification_levels[:regular],
     tracking: TopicUser.notification_levels[:tracking])
  }

  # Class methods
  class << self

    # Enums
    def notification_levels
      NotificationLevels.topic_levels
    end

    def notification_reasons
      @notification_reasons ||= Enum.new(created_topic: 1,
                                         user_changed: 2,
                                         user_interacted: 3,
                                         created_post: 4,
                                         auto_watch: 5,
                                         auto_watch_category: 6,
                                         auto_mute_category: 7,
                                         auto_track_category: 8,
                                         plugin_changed: 9,
                                         auto_watch_tag: 10,
                                         auto_mute_tag: 11,
                                         auto_track_tag: 12)
    end

    def auto_notification(user_id, topic_id, reason, notification_level)
      should_change = TopicUser
        .where(user_id: user_id, topic_id: topic_id)
        .where("notifications_reason_id IS NULL OR (notification_level < :min AND notification_level > :max)", min: notification_level, max: notification_levels[:regular])
        .exists?

      change(user_id, topic_id, notification_level: notification_level, notifications_reason_id: reason) if should_change
    end

    def auto_notification_for_staging(user_id, topic_id, reason, notification_level = notification_levels[:watching])
      change(user_id, topic_id, notification_level: notification_level, notifications_reason_id: reason)
    end

    def unwatch_categories!(user, category_ids)
      track_threshold = user.user_option.auto_track_topics_after_msecs

      sql = <<~SQL
        UPDATE topic_users tu
        SET notification_level = CASE
          WHEN t.user_id = :user_id THEN :watching
          WHEN total_msecs_viewed > :track_threshold AND :track_threshold >= 0 THEN :tracking
          ELSE :regular
        end
        FROM topics t
        WHERE t.id = tu.topic_id AND tu.notification_level <> :muted AND category_id IN (:category_ids) AND tu.user_id = :user_id
      SQL

      DB.exec(sql,
        watching: notification_levels[:watching],
        tracking: notification_levels[:tracking],
        regular: notification_levels[:regular],
        muted: notification_levels[:muted],
        category_ids: category_ids,
        user_id: user.id,
        track_threshold: track_threshold
      )
    end

    # Find the information specific to a user in a forum topic
    def lookup_for(user, topics)
      # If the user isn't logged in, there's no last read posts
      return {} if user.blank? || topics.blank?

      topic_ids = topics.map(&:id)
      create_lookup(TopicUser.where(topic_id: topic_ids, user_id: user.id))
    end

    def create_lookup(topic_users)
      topic_users = topic_users.to_a
      result = {}
      return result if topic_users.blank?
      topic_users.each { |ftu| result[ftu.topic_id] = ftu }
      result
    end

    def get(topic, user)
      topic = topic.id if topic.is_a?(Topic)
      user = user.id if user.is_a?(User)
      TopicUser.find_by(topic_id: topic, user_id: user)
    end

    # Change attributes for a user (creates a record when none is present). First it tries an update
    # since there's more likely to be an existing record than not. If the update returns 0 rows affected
    # it then creates the row instead.
    def change(user_id, topic_id, attrs)
      # Sometimes people pass objs instead of the ids. We can handle that.
      topic_id = topic_id.id if topic_id.is_a?(::Topic)
      user_id = user_id.id if user_id.is_a?(::User)

      topic_id = topic_id.to_i
      user_id = user_id.to_i

      TopicUser.transaction do
        attrs = attrs.dup
        if attrs[:notification_level]
          attrs[:notifications_changed_at] ||= DateTime.now
          attrs[:notifications_reason_id] ||= TopicUser.notification_reasons[:user_changed]
        end
        attrs_array = attrs.to_a

        attrs_sql = attrs_array.map { |t| "#{t[0]} = ?" }.join(", ")
        vals = attrs_array.map { |t| t[1] }
        rows = TopicUser.where(topic_id: topic_id, user_id: user_id).update_all([attrs_sql, *vals])

        if rows == 0
          create_missing_record(user_id, topic_id, attrs)
        end
      end

      if attrs[:notification_level]
        notification_level_change(user_id, topic_id, attrs[:notification_level], attrs[:notifications_reason_id])
      end

    rescue ActiveRecord::RecordNotUnique
      # In case of a race condition to insert, do nothing
    end

    def notification_level_change(user_id, topic_id, notification_level, reason_id)
      message = { notification_level_change: notification_level }
      message[:notifications_reason_id] = reason_id if reason_id
      MessageBus.publish("/topic/#{topic_id}", message, user_ids: [user_id])

      DiscourseEvent.trigger(:topic_notification_level_changed,
        notification_level,
        user_id,
        topic_id
      )

    end

    def create_missing_record(user_id, topic_id, attrs)
      now = DateTime.now

      unless attrs[:notification_level]
        category_notification_level = CategoryUser.where(user_id: user_id)
          .where("category_id IN (SELECT category_id FROM topics WHERE id = :id)", id: topic_id)
          .where("notification_level IN (:levels)", levels: [CategoryUser.notification_levels[:watching],
                        CategoryUser.notification_levels[:tracking]])
          .order("notification_level DESC")
          .limit(1)
          .pluck(:notification_level)
          .first

        tag_notification_level = TagUser.where(user_id: user_id)
          .where("tag_id IN (SELECT tag_id FROM topic_tags WHERE topic_id = :id)", id: topic_id)
          .where("notification_level IN (:levels)", levels: [CategoryUser.notification_levels[:watching],
                        CategoryUser.notification_levels[:tracking]])
          .order("notification_level DESC")
          .limit(1)
          .pluck(:notification_level)
          .first

        if category_notification_level && !(tag_notification_level && (tag_notification_level > category_notification_level))
          attrs[:notification_level] = category_notification_level
          attrs[:notifications_changed_at] = DateTime.now
          attrs[:notifications_reason_id] = category_notification_level == CategoryUser.notification_levels[:watching] ?
              TopicUser.notification_reasons[:auto_watch_category] :
              TopicUser.notification_reasons[:auto_track_category]

        elsif tag_notification_level
          attrs[:notification_level] = tag_notification_level
          attrs[:notifications_changed_at] = DateTime.now
          attrs[:notifications_reason_id] = tag_notification_level == TagUser.notification_levels[:watching] ?
              TopicUser.notification_reasons[:auto_watch_tag] :
              TopicUser.notification_reasons[:auto_track_tag]
        end

      end

      unless attrs[:notification_level]
        if Topic.private_messages.where(id: topic_id).exists? &&
           Notification.where(
             user_id: user_id,
             topic_id: topic_id,
             notification_type: Notification.types[:invited_to_private_message]
           ).exists?

          group_notification_level = Group
            .joins("LEFT OUTER JOIN group_users gu ON gu.group_id = groups.id AND gu.user_id = #{user_id}")
            .joins("LEFT OUTER JOIN topic_allowed_groups tag ON tag.topic_id = #{topic_id}")
            .where("gu.id IS NOT NULL AND tag.id IS NOT NULL")
            .pluck(:default_notification_level)
            .first

          if group_notification_level.present?
            attrs[:notification_level] = group_notification_level
          else
            attrs[:notification_level] = notification_levels[:watching]
          end
        else
          auto_track_after = UserOption.where(user_id: user_id).pluck(:auto_track_topics_after_msecs).first
          auto_track_after ||= SiteSetting.default_other_auto_track_topics_after_msecs

          if auto_track_after >= 0 && auto_track_after <= (attrs[:total_msecs_viewed].to_i || 0)
            attrs[:notification_level] ||= notification_levels[:tracking]
          end
        end
      end

      TopicUser.create!(attrs.merge!(
        user_id: user_id,
        topic_id: topic_id,
        first_visited_at: now ,
        last_visited_at: now
      ))
    end

    def track_visit!(topic_id, user_id)
      now = DateTime.now
      rows = TopicUser.where(topic_id: topic_id, user_id: user_id).update_all(last_visited_at: now)

      if rows == 0
        change(user_id, topic_id, last_visited_at: now, first_visited_at: now)
      end
    end

    # Update the last read and the last seen post count, but only if it doesn't exist.
    # This would be a lot easier if psql supported some kind of upsert
    UPDATE_TOPIC_USER_SQL = "UPDATE topic_users
                                    SET
                                      last_read_post_number = GREATEST(:post_number, tu.last_read_post_number),
                                      highest_seen_post_number = t.highest_post_number,
                                      total_msecs_viewed = LEAST(tu.total_msecs_viewed + :msecs,86400000),
                                      notification_level =
                                         case when tu.notifications_reason_id is null and (tu.total_msecs_viewed + :msecs) >
                                            coalesce(uo.auto_track_topics_after_msecs,:threshold) and
                                            coalesce(uo.auto_track_topics_after_msecs, :threshold) >= 0 then
                                              :tracking
                                         else
                                            tu.notification_level
                                         end
                                  FROM topic_users tu
                                  join topics t on t.id = tu.topic_id
                                  join users u on u.id = :user_id
                                  join user_options uo on uo.user_id = :user_id
                                  WHERE
                                       tu.topic_id = topic_users.topic_id AND
                                       tu.user_id = topic_users.user_id AND
                                       tu.topic_id = :topic_id AND
                                       tu.user_id = :user_id
                                  RETURNING
                                    topic_users.notification_level, tu.notification_level old_level, tu.last_read_post_number
                                "

    UPDATE_TOPIC_USER_SQL_STAFF = UPDATE_TOPIC_USER_SQL.gsub("highest_post_number", "highest_staff_post_number")

    INSERT_TOPIC_USER_SQL = "INSERT INTO topic_users (user_id, topic_id, last_read_post_number, highest_seen_post_number, last_visited_at, first_visited_at, notification_level)
                  SELECT :user_id, :topic_id, :post_number, ft.highest_post_number, :now, :now, :new_status
                  FROM topics AS ft
                  JOIN users u on u.id = :user_id
                  WHERE ft.id = :topic_id
                    AND NOT EXISTS(SELECT 1
                                   FROM topic_users AS ftu
                                   WHERE ftu.user_id = :user_id and ftu.topic_id = :topic_id)"

    INSERT_TOPIC_USER_SQL_STAFF = INSERT_TOPIC_USER_SQL.gsub("highest_post_number", "highest_staff_post_number")

    def update_last_read(user, topic_id, post_number, new_posts_read, msecs, opts = {})
      return if post_number.blank?
      msecs = 0 if msecs.to_i < 0

      args = {
        user_id: user.id,
        topic_id: topic_id,
        post_number: post_number,
        now: DateTime.now,
        msecs: msecs,
        tracking: notification_levels[:tracking],
        threshold: SiteSetting.default_other_auto_track_topics_after_msecs
      }

      # In case anyone seens "highest_seen_post_number" and gets confused, like I do.
      # highest_seen_post_number represents the highest_post_number of the topic when
      # the user visited it. It may be out of alignment with last_read, meaning
      # ... user visited the topic but did not read the posts
      #
      # 86400000 = 1 day
      rows =
        if user.staff?
          DB.query(UPDATE_TOPIC_USER_SQL_STAFF, args)
        else
          DB.query(UPDATE_TOPIC_USER_SQL, args)
        end

      if rows.length == 1
        before = rows[0].old_level.to_i
        after = rows[0].notification_level.to_i
        before_last_read = rows[0].last_read_post_number.to_i

        if before_last_read < post_number
          # The user read at least one new post
          TopicTrackingState.publish_read(topic_id, post_number, user.id, after)
        end

        if new_posts_read > 0
          user.update_posts_read!(new_posts_read, mobile: opts[:mobile])
        end

        if before != after
          notification_level_change(user.id, topic_id, after, nil)
        end
      end

      if rows.length == 0
        # The user read at least one post in a topic that they haven't viewed before.
        args[:new_status] = notification_levels[:regular]
        if (user.user_option.auto_track_topics_after_msecs || SiteSetting.default_other_auto_track_topics_after_msecs) == 0
          args[:new_status] = notification_levels[:tracking]
        end
        TopicTrackingState.publish_read(topic_id, post_number, user.id, args[:new_status])

        user.update_posts_read!(new_posts_read, mobile: opts[:mobile])

        begin
          if user.staff?
            DB.exec(INSERT_TOPIC_USER_SQL_STAFF, args)
          else
            DB.exec(INSERT_TOPIC_USER_SQL, args)
          end
        rescue PG::UniqueViolation
          # if record is inserted between two statements this can happen
          # we retry once to avoid failing the req
          if opts[:retry]
            raise
          else
            opts[:retry] = true
            update_last_read(user, topic_id, post_number, new_posts_read, msecs, opts)
          end
        end

        notification_level_change(user.id, topic_id, args[:new_status], nil)
      end
    end

  end

  def self.update_post_action_cache(opts = {})
    user_id = opts[:user_id]
    post_id = opts[:post_id]
    topic_id = opts[:topic_id]
    action_type = opts[:post_action_type]

    action_type_name = "liked" if action_type == :like
    action_type_name = "bookmarked" if action_type == :bookmark

    raise ArgumentError, "action_type" if action_type && !action_type_name

    unless action_type_name
      update_post_action_cache(opts.merge(post_action_type: :like))
      update_post_action_cache(opts.merge(post_action_type: :bookmark))
      return
    end

    builder = DB.build <<~SQL
      UPDATE topic_users tu
      SET #{action_type_name} = x.state
      FROM (
        SELECT CASE WHEN EXISTS (
          SELECT 1
          FROM post_actions pa
          JOIN posts p on p.id = pa.post_id
          JOIN topics t ON t.id = p.topic_id
          WHERE pa.deleted_at IS NULL AND
                p.deleted_at IS NULL AND
                t.deleted_at IS NULL AND
                pa.post_action_type_id = :action_type_id AND
                tu2.topic_id = t.id AND
                tu2.user_id = pa.user_id
          LIMIT 1
        ) THEN true ELSE false END state, tu2.topic_id, tu2.user_id
        FROM topic_users tu2
        /*where*/
      ) x
      WHERE x.topic_id = tu.topic_id AND x.user_id = tu.user_id AND x.state != tu.#{action_type_name}
    SQL

    if user_id
      builder.where("tu2.user_id = :user_id", user_id: user_id)
    end

    if topic_id
      builder.where("tu2.topic_id = :topic_id", topic_id: topic_id)
    end

    if post_id
      builder.where("tu2.topic_id IN (SELECT topic_id FROM posts WHERE id = :post_id)", post_id: post_id)
      builder.where("tu2.user_id IN (SELECT user_id FROM post_actions
                                     WHERE post_id = :post_id AND
                                           post_action_type_id = :action_type_id)")
    end

    builder.exec(action_type_id: PostActionType.types[action_type])
  end

  # cap number of unread topics at count, bumping up highest_seen / last_read if needed
  def self.cap_unread!(user_id, count)
    sql = <<SQL
    UPDATE topic_users tu
    SET last_read_post_number = max_number,
        highest_seen_post_number = max_number
    FROM (
      SELECT MAX(post_number) max_number, p.topic_id FROM posts p
      WHERE deleted_at IS NULL
      GROUP BY p.topic_id
    ) m
    WHERE tu.user_id = :user_id AND
          m.topic_id = tu.topic_id AND
          tu.topic_id IN (
            #{TopicTrackingState.report_raw_sql(skip_new: true, select: "topics.id")}
            offset :count
          )
SQL

    DB.exec(sql, user_id: user_id, count: count)
  end

  def self.ensure_consistency!(topic_id = nil)
    update_post_action_cache(topic_id: topic_id)

    # TODO this needs some reworking, when we mark stuff skipped
    # we up these numbers so they are not in-sync
    # the simple fix is to add a column here, but table is already quite big
    # long term we want to split up topic_users and allow for this better
    builder = DB.build <<~SQL
      UPDATE topic_users t
        SET
          last_read_post_number = LEAST(GREATEST(last_read, last_read_post_number), max_post_number),
          highest_seen_post_number = LEAST(max_post_number,GREATEST(t.highest_seen_post_number, last_read))
      FROM (
        SELECT topic_id, user_id, MAX(post_number) last_read
        FROM post_timings
        GROUP BY topic_id, user_id
      ) as X
      JOIN (
        SELECT p.topic_id, MAX(p.post_number) max_post_number from posts p
        GROUP BY p.topic_id
      ) as Y on Y.topic_id = X.topic_id
      /*where*/
    SQL

    builder.where <<~SQL
      X.topic_id = t.topic_id AND
      X.user_id = t.user_id AND
      (
        last_read_post_number <> LEAST(GREATEST(last_read, last_read_post_number), max_post_number) OR
        highest_seen_post_number <> LEAST(max_post_number,GREATEST(t.highest_seen_post_number, last_read))
      )
    SQL

    if topic_id
      builder.where("t.topic_id = :topic_id", topic_id: topic_id)
    end

    builder.exec
  end

end

# == Schema Information
#
# Table name: topic_users
#
#  user_id                  :integer          not null
#  topic_id                 :integer          not null
#  posted                   :boolean          default(FALSE), not null
#  last_read_post_number    :integer
#  highest_seen_post_number :integer
#  last_visited_at          :datetime
#  first_visited_at         :datetime
#  notification_level       :integer          default(1), not null
#  notifications_changed_at :datetime
#  notifications_reason_id  :integer
#  total_msecs_viewed       :integer          default(0), not null
#  cleared_pinned_at        :datetime
#  id                       :integer          not null, primary key
#  last_emailed_post_number :integer
#  liked                    :boolean          default(FALSE)
#  bookmarked               :boolean          default(FALSE)
#
# Indexes
#
#  index_topic_users_on_topic_id_and_user_id  (topic_id,user_id) UNIQUE
#  index_topic_users_on_user_id_and_topic_id  (user_id,topic_id) UNIQUE
#
