class UserStat < ActiveRecord::Base

  belongs_to :user
  after_save :trigger_badges

  def self.ensure_consistency!(last_seen = 1.hour.ago)
    reset_bounce_scores
    update_view_counts(last_seen)
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
    exec_sql "UPDATE user_stats SET topics_entered = X.c
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
    ", seen_at: last_seen

    # Update denormalzied posts_read_count
    exec_sql "UPDATE user_stats SET posts_read_count = X.c
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
    ", seen_at: last_seen
  end

  def update_topic_reply_count
    self.topic_reply_count =
        Topic
        .where(['id in (
              SELECT topic_id FROM posts p
              JOIN topics t2 ON t2.id = p.topic_id
              WHERE p.deleted_at IS NULL AND
                t2.user_id <> p.user_id AND
                p.user_id = ?
              )', self.user_id])
        .count
  end

  MAX_TIME_READ_DIFF = 100
  # attempt to add total read time to user based on previous time this was called
  def update_time_read!
    if last_seen = last_seen_cached
      diff = (Time.now.to_f - last_seen.to_f).round
      if diff > 0 && diff < MAX_TIME_READ_DIFF
        UserStat.where(user_id: id, time_read: time_read).update_all ["time_read = time_read + ?", diff]
      end
    end
    cache_last_seen(Time.now.to_f)
  end

  protected

  def trigger_badges
    BadgeGranter.queue_badge_grant(Badge::Trigger::UserChange, user: self.user)
  end

  private

  def last_seen_key
    @last_seen_key ||= "user-last-seen:#{id}"
  end

  def last_seen_cached
    $redis.get(last_seen_key)
  end

  def cache_last_seen(val)
    $redis.set(last_seen_key, val)
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
#  bounce_score             :integer          default(0), not null
#  reset_bounce_score_after :datetime
#
