# frozen_string_literal: true
class UserStat < ActiveRecord::Base

  belongs_to :user
  after_save :trigger_badges

  def self.ensure_consistency!(last_seen = 1.hour.ago)
    reset_bounce_scores
    update_distinct_badge_count
    update_view_counts(last_seen)
    update_first_unread(last_seen)
  end

  def self.update_first_unread(last_seen, limit: 10_000)
    DB.exec(<<~SQL, min_date: last_seen, limit: limit, now: 10.minutes.ago)
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
    UserStat.where("reset_bounce_score_after < now()")
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

    # Update denormalzied posts_read_count
    DB.exec(<<~SQL, seen_at: last_seen)
      UPDATE user_stats SET posts_read_count = X.c
      FROM
      (SELECT pt.user_id,
              COUNT(*) AS c
       FROM users AS u
       JOIN post_timings AS pt ON pt.user_id = u.id
       JOIN topics t ON t.id = pt.topic_id
       WHERE u.last_seen_at > :seen_at AND
             t.archetype = 'regular' AND
             t.deleted_at IS NULL
       GROUP BY pt.user_id) AS X
       WHERE X.user_id = user_stats.user_id AND
             X.c <> posts_read_count
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

  # topic_reply_count is a count of posts in other users' topics
  def update_topic_reply_count
    self.topic_reply_count = Topic
      .joins("INNER JOIN posts ON topics.id = posts.topic_id AND topics.user_id <> posts.user_id")
      .where("posts.deleted_at IS NULL AND posts.user_id = ?", self.user_id)
      .distinct
      .count
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
#  topic_reply_count        :integer          default(0), not null
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
#
