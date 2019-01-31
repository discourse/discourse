# frozen_string_literal: true
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

  # topic_reply_count is a count of posts in other users' topics
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
    $redis.get(last_seen_key(id))
  end

  def self.cache_last_seen(id, val)
    $redis.setex(last_seen_key(id), MAX_TIME_READ_DIFF, val)
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
#
