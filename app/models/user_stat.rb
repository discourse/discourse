class UserStat < ActiveRecord::Base

  belongs_to :user

  # Updates the denormalized view counts for all users
  def self.update_view_counts

    # NOTE: we only update the counts for users we have seen in the last hour
    #  this avoids a very expensive query that may run on the entire user base
    #  we also ensure we only touch the table if data changes

    # Update denormalized topics_entered
    exec_sql "UPDATE user_stats SET topics_entered = X.c
             FROM
            (SELECT v.user_id,
                    COUNT(DISTINCT parent_id) AS c
             FROM views AS v
             WHERE parent_type = 'Topic' AND v.user_id IN (
                SELECT u1.id FROM users u1 where u1.last_seen_at > :seen_at
             )
             GROUP BY v.user_id) AS X
            WHERE
                    X.user_id = user_stats.user_id AND
                    X.c <> topics_entered
    ", seen_at: 1.hour.ago

    # Update denormalzied posts_read_count
    exec_sql "UPDATE user_stats SET posts_read_count = X.c
              FROM
              (SELECT pt.user_id,
                      COUNT(*) AS c
               FROM post_timings AS pt
               WHERE pt.user_id IN (
                  SELECT u1.id FROM users u1 where u1.last_seen_at > :seen_at
               )
               GROUP BY pt.user_id) AS X
               WHERE X.user_id = user_stats.user_id AND
                     X.c <> posts_read_count
    ", seen_at: 1.hour.ago
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
    last_seen_key = "user-last-seen:#{id}"
    last_seen = $redis.get(last_seen_key)
    if last_seen.present?
      diff = (Time.now.to_f - last_seen.to_f).round
      if diff > 0 && diff < MAX_TIME_READ_DIFF
        UserStat.where(user_id: id, time_read: time_read).update_all ["time_read = time_read + ?", diff]
      end
    end
    $redis.set(last_seen_key, Time.now.to_f)
  end

end

# == Schema Information
#
# Table name: user_stats
#
#  user_id           :integer          not null, primary key
#  has_custom_avatar :boolean          default(FALSE), not null
#  topics_entered    :integer          default(0), not null
#  time_read         :integer          default(0), not null
#  days_visited      :integer          default(0), not null
#  posts_read_count  :integer          default(0), not null
#  likes_given       :integer          default(0), not null
#  likes_received    :integer          default(0), not null
#  topic_reply_count :integer          default(0), not null
#

