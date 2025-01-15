# frozen_string_literal: true
class UserStat < ActiveRecord::Base
  belongs_to :user
  after_save :trigger_badges

  self.ignored_columns = ["topic_reply_count"] # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy

  def self.ensure_consistency!(last_seen = 1.hour.ago)
    reset_bounce_scores
    update_distinct_badge_count
    update_view_counts(last_seen)
    update_first_unread(last_seen)
    update_first_unread_pm(last_seen)
  end

  UPDATE_UNREAD_MINUTES_AGO = 10
  UPDATE_UNREAD_USERS_LIMIT = 10_000

  def self.update_first_unread_pm(last_seen, limit: UPDATE_UNREAD_USERS_LIMIT)
    DB.exec(
      <<~SQL,
    UPDATE user_stats us
    SET first_unread_pm_at = COALESCE(Z.min_date, :now)
    FROM (
      SELECT
        u1.id user_id,
        X.min_date
      FROM users u1
      LEFT JOIN (
        SELECT
          tau.user_id,
          MIN(t.updated_at) min_date
        FROM topic_allowed_users tau
        INNER JOIN topics t ON t.id = tau.topic_id
        INNER JOIN users u ON u.id = tau.user_id
        LEFT JOIN topic_users tu ON t.id = tu.topic_id AND tu.user_id = tau.user_id
        #{SiteSetting.whispers_allowed_groups_map.any? ? "LEFT JOIN group_users gu ON gu.group_id IN (:whisperers_group_ids) AND gu.user_id = u.id" : ""}
        WHERE t.deleted_at IS NULL
        AND t.archetype = :archetype
        AND tu.last_read_post_number < CASE
                                       WHEN u.admin OR u.moderator #{SiteSetting.whispers_allowed_groups_map.any? ? "OR gu.id IS NOT NULL" : ""}
                                       THEN t.highest_staff_post_number
                                       ELSE t.highest_post_number
                                       END
        AND (COALESCE(tu.notification_level, 1) >= 2)
        AND tau.user_id IN (
          SELECT id
          FROM users
          WHERE last_seen_at IS NOT NULL
          AND last_seen_at > :last_seen
          ORDER BY last_seen_at DESC
          LIMIT :limit
        )
        GROUP BY tau.user_id
      ) AS X ON X.user_id = u1.id
      WHERE u1.id IN (
        SELECT id
        FROM users
        WHERE last_seen_at IS NOT NULL
        AND last_seen_at > :last_seen
        ORDER BY last_seen_at DESC
        LIMIT :limit
      )
    ) AS Z
    WHERE us.user_id = Z.user_id
    SQL
      archetype: Archetype.private_message,
      now: UPDATE_UNREAD_MINUTES_AGO.minutes.ago,
      last_seen: last_seen,
      limit: limit,
      whisperers_group_ids: SiteSetting.whispers_allowed_groups_map,
    )
  end

  def self.update_first_unread(last_seen, limit: UPDATE_UNREAD_USERS_LIMIT)
    DB.exec(<<~SQL, min_date: last_seen, limit: limit, now: UPDATE_UNREAD_MINUTES_AGO.minutes.ago)
      UPDATE user_stats us
      SET first_unread_at = COALESCE(Y.min_date, :now)
      FROM (
        SELECT u1.id user_id,
           X.min min_date
        FROM users u1
        LEFT JOIN
          (SELECT u.id AS user_id,
                  min(topics.updated_at) min
           FROM users u
           LEFT JOIN topic_users tu ON tu.user_id = u.id
           LEFT JOIN topics ON tu.topic_id = topics.id
           JOIN user_stats AS us ON us.user_id = u.id
           JOIN user_options AS uo ON uo.user_id = u.id
           JOIN categories c ON c.id = topics.category_id
           WHERE u.id IN (
               SELECT id
               FROM users
               WHERE last_seen_at IS NOT NULL
                AND last_seen_at > :min_date
                ORDER BY last_seen_at DESC
                LIMIT :limit
              )
             AND topics.archetype <> 'private_message'
             AND (("topics"."deleted_at" IS NULL
                   AND tu.last_read_post_number < CASE
                                                      WHEN u.admin
                                                           OR u.moderator THEN topics.highest_staff_post_number
                                                      ELSE topics.highest_post_number
                                                  END
                   AND COALESCE(tu.notification_level, 1) >= 2)
                  OR (1=0))
             AND (topics.visible
                  OR u.admin
                  OR u.moderator)
             AND topics.deleted_at IS NULL
             AND (NOT c.read_restricted
                  OR u.admin
                  OR category_id IN
                    (SELECT c2.id
                     FROM categories c2
                     JOIN category_groups cg ON cg.category_id = c2.id
                     JOIN group_users gu ON gu.user_id = u.id
                     AND cg.group_id = gu.group_id
                     WHERE c2.read_restricted ))
             AND NOT EXISTS
               (SELECT 1
                FROM category_users cu
                WHERE last_read_post_number IS NULL
                  AND cu.user_id = u.id
                  AND cu.category_id = topics.category_id
                  AND cu.notification_level = 0)
           GROUP BY u.id,
                    u.username) AS X ON X.user_id = u1.id
        WHERE u1.id IN
            (
             SELECT id
             FROM users
             WHERE last_seen_at IS NOT NULL
              AND last_seen_at > :min_date
              ORDER BY last_seen_at DESC
              LIMIT :limit
            )
      ) Y
      WHERE Y.user_id = us.user_id
    SQL
  end

  def self.reset_bounce_scores
    UserStat
      .where("reset_bounce_score_after < now()")
      .where("bounce_score > 0")
      .update_all(bounce_score: 0)
  end

  # Updates the denormalized view counts for all users
  def self.update_view_counts(last_seen = 1.hour.ago)
    # NOTE: we only update the counts for users we have seen in the last hour
    #  this avoids a very expensive query that may run on the entire user base
    #  we also ensure we only touch the table if data changes

    # Update denormalized topics_entered
    DB.exec(<<~SQL, seen_at: last_seen)
      UPDATE user_stats SET topics_entered = X.c
       FROM
      (SELECT v.user_id, COUNT(topic_id) AS c
       FROM topic_views AS v
       WHERE v.user_id IN (
          SELECT u1.id FROM users u1 where u1.last_seen_at > :seen_at
       )
       GROUP BY v.user_id) AS X
      WHERE
        X.user_id = user_stats.user_id AND
        X.c <> topics_entered
    SQL

    # Update denormalized posts_read_count
    DB.exec(<<~SQL, seen_at: last_seen)
      WITH filtered_users AS (
        SELECT id FROM users u
        JOIN user_stats ON user_id = u.id
        WHERE last_seen_at > :seen_at
        AND posts_read_count < 10000
      )
      UPDATE user_stats SET posts_read_count = X.c
      FROM (SELECT pt.user_id, COUNT(*) as c
            FROM filtered_users AS u
            JOIN post_timings AS pt ON pt.user_id = u.id
            JOIN topics t ON t.id = pt.topic_id
            WHERE t.archetype = 'regular'
            AND t.deleted_at IS NULL
            GROUP BY pt.user_id
           ) AS X
      WHERE X.user_id = user_stats.user_id
      AND X.c <> posts_read_count
    SQL
  end

  def self.update_distinct_badge_count(user_id = nil)
    sql = <<~SQL
      UPDATE user_stats
      SET distinct_badge_count = x.distinct_badge_count
      FROM (
        SELECT users.id user_id, COUNT(distinct user_badges.badge_id) distinct_badge_count
        FROM users
        LEFT JOIN user_badges ON user_badges.user_id = users.id
                              AND (user_badges.badge_id IN (SELECT id FROM badges WHERE enabled))
        GROUP BY users.id
      ) x
      WHERE user_stats.user_id = x.user_id AND user_stats.distinct_badge_count <> x.distinct_badge_count
    SQL

    sql = sql + " AND user_stats.user_id = #{user_id.to_i}" if user_id

    DB.exec sql
  end

  def update_distinct_badge_count
    self.class.update_distinct_badge_count(self.user_id)
  end

  def self.update_draft_count(user_id = nil)
    if user_id.present?
      draft_count = DB.query_single(<<~SQL, user_id: user_id).first
        UPDATE user_stats
        SET draft_count = (SELECT COUNT(*) FROM drafts WHERE user_id = :user_id)
        WHERE user_id = :user_id
        RETURNING draft_count
      SQL

      MessageBus.publish(
        "/user-drafts/#{user_id}",
        { draft_count: draft_count },
        user_ids: [user_id],
      )
    else
      DB.exec <<~SQL
        UPDATE user_stats
        SET draft_count = new_user_stats.draft_count
        FROM (SELECT user_stats.user_id, COUNT(drafts.id) draft_count
              FROM user_stats
              LEFT JOIN drafts ON user_stats.user_id = drafts.user_id
              GROUP BY user_stats.user_id) new_user_stats
        WHERE user_stats.user_id = new_user_stats.user_id
          AND user_stats.draft_count <> new_user_stats.draft_count
      SQL
    end
  end

  # topic_reply_count is a count of posts in other users' topics
  def calc_topic_reply_count!(start_time = nil)
    sql = <<~SQL
      SELECT COUNT(DISTINCT posts.topic_id) AS count
      FROM posts
      INNER JOIN topics ON topics.id = posts.topic_id
      WHERE posts.user_id = ?
      AND topics.user_id <> posts.user_id
      AND posts.deleted_at IS NULL AND topics.deleted_at IS NULL
      AND topics.archetype <> 'private_message'
      #{start_time.nil? ? "" : "AND posts.created_at > ?"}
    SQL
    if start_time.nil?
      DB.query_single(sql, self.user_id).first
    else
      DB.query_single(sql, self.user_id, start_time).first
    end
  end

  def any_posts
    user.posts.exists?
  end

  MAX_TIME_READ_DIFF = 100
  # attempt to add total read time to user based on previous time this was called
  def self.update_time_read!(id)
    if last_seen = last_seen_cached(id)
      diff = (Time.now.to_f - last_seen.to_f).round
      if diff > 0 && diff < MAX_TIME_READ_DIFF
        update_args = ["time_read = time_read + ?", diff]
        UserStat.where(user_id: id).update_all(update_args)
        UserVisit.where(user_id: id, visited_at: Time.zone.now.to_date).update_all(update_args)
      end
    end
    cache_last_seen(id, Time.now.to_f)
  end

  def update_time_read!
    UserStat.update_time_read!(id)
  end

  def reset_bounce_score!
    update_columns(reset_bounce_score_after: nil, bounce_score: 0)
  end

  def self.last_seen_key(id)
    # frozen
    -"user-last-seen:#{id}"
  end

  def self.last_seen_cached(id)
    Discourse.redis.get(last_seen_key(id))
  end

  def self.cache_last_seen(id, val)
    Discourse.redis.setex(last_seen_key(id), MAX_TIME_READ_DIFF, val)
  end

  def update_pending_posts
    update(pending_posts_count: user.pending_posts.count)
    MessageBus.publish(
      "/u/#{user.username_lower}/counters",
      { pending_posts_count: pending_posts_count },
      user_ids: [user.id],
      group_ids: [Group::AUTO_GROUPS[:staff]],
    )
  end

  protected

  def trigger_badges
    BadgeGranter.queue_badge_grant(Badge::Trigger::UserChange, user: self.user)
  end
end

# == Schema Information
#
# Table name: user_stats
#
#  user_id                  :integer          not null, primary key
#  topics_entered           :integer          default(0), not null
#  time_read                :integer          default(0), not null
#  days_visited             :integer          default(0), not null
#  posts_read_count         :integer          default(0), not null
#  likes_given              :integer          default(0), not null
#  likes_received           :integer          default(0), not null
#  new_since                :datetime         not null
#  read_faq                 :datetime
#  first_post_created_at    :datetime
#  post_count               :integer          default(0), not null
#  topic_count              :integer          default(0), not null
#  bounce_score             :float            default(0.0), not null
#  reset_bounce_score_after :datetime
#  flags_agreed             :integer          default(0), not null
#  flags_disagreed          :integer          default(0), not null
#  flags_ignored            :integer          default(0), not null
#  first_unread_at          :datetime         not null
#  distinct_badge_count     :integer          default(0), not null
#  first_unread_pm_at       :datetime         not null
#  digest_attempted_at      :datetime
#  post_edits_count         :integer
#  draft_count              :integer          default(0), not null
#  pending_posts_count      :integer          default(0), not null
#
