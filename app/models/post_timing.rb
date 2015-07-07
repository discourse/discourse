class PostTiming < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  validates_presence_of :post_number
  validates_presence_of :msecs


  def self.pretend_read(topic_id, actual_read_post_number, pretend_read_post_number)
    # This is done in SQL cause the logic is quite tricky and we want to do this in one db hit
    #
    exec_sql("INSERT INTO post_timings(topic_id, user_id, post_number, msecs)
              SELECT :topic_id, user_id, :pretend_read_post_number, 1
              FROM post_timings pt
              WHERE topic_id = :topic_id AND
                    post_number = :actual_read_post_number AND
                    NOT EXISTS (
                        SELECT 1 FROM post_timings pt1
                        WHERE pt1.topic_id = pt.topic_id AND
                              pt1.post_number = :pretend_read_post_number AND
                              pt1.user_id = pt.user_id
                    )
             ",
                pretend_read_post_number: pretend_read_post_number,
                topic_id: topic_id,
                actual_read_post_number: actual_read_post_number
            )

    TopicUser.ensure_consistency!(topic_id)
  end

  def self.record_new_timing(args)
    begin
      exec_sql("INSERT INTO post_timings (topic_id, user_id, post_number, msecs)
                SELECT :topic_id, :user_id, :post_number, :msecs
                WHERE NOT EXISTS(SELECT 1 FROM post_timings
                                 WHERE topic_id = :topic_id
                                  AND user_id = :user_id
                                  AND post_number = :post_number)",
             args)
    rescue PG::UniqueViolation
       # concurrency is hard, we are not running serialized so this can possibly
       # still happen, if it happens we just don't care, its an invalid record anyway
       return
    end

    Post.where(['topic_id = :topic_id and post_number = :post_number', args]).update_all 'reads = reads + 1'
    UserStat.where(user_id: args[:user_id]).update_all 'posts_read_count = posts_read_count + 1'
  end

  # Increases a timer if a row exists, otherwise create it
  def self.record_timing(args)
    rows = exec_sql_row_count("UPDATE post_timings
                               SET msecs = msecs + :msecs
                               WHERE topic_id = :topic_id
                                AND user_id = :user_id
                                AND post_number = :post_number",
                                args)

    record_new_timing(args) if rows == 0
  end


  def self.destroy_for(user_id, topic_ids)
    PostTiming.transaction do
      PostTiming.delete_all(['user_id = ? and topic_id in (?)', user_id, topic_ids])
      TopicUser.delete_all(['user_id = ? and topic_id in (?)', user_id, topic_ids])
    end
  end

  MAX_READ_TIME_PER_BATCH = 60*1000.0

  def self.process_timings(current_user, topic_id, topic_time, timings, opts={})
    current_user.user_stat.update_time_read!

    max_time_per_post = ((Time.now - current_user.created_at) * 1000.0)
    max_time_per_post = MAX_READ_TIME_PER_BATCH if max_time_per_post > MAX_READ_TIME_PER_BATCH

    highest_seen = 1

    join_table = []

    i = timings.length
    while i > 0
      i -= 1
      timings[i][1] = max_time_per_post if timings[i][1] > max_time_per_post
      timings.delete_at(i) if timings[i][0] < 1
    end

    timings.each_with_index do |(post_number, time), index|

        join_table << "SELECT #{topic_id.to_i} topic_id, #{post_number.to_i} post_number,
                       #{current_user.id.to_i} user_id, #{time.to_i} msecs, #{index} idx"


        highest_seen = post_number.to_i > highest_seen ?
                       post_number.to_i : highest_seen
    end

    if join_table.length > 0
      sql = <<SQL

      UPDATE post_timings t
      SET msecs = t.msecs + x.msecs
      FROM (#{join_table.join(" UNION ALL ")}) x
      WHERE x.topic_id = t.topic_id AND
            x.post_number = t.post_number AND
            x.user_id = t.user_id
      RETURNING x.idx
SQL

      result = exec_sql(sql)
      result.type_map = SqlBuilder.pg_type_map
      existing = Set.new(result.column_values(0))

      timings.each_with_index do |(post_number, time),index|
        unless existing.include?(index)
          PostTiming.record_new_timing(topic_id: topic_id,
                                 post_number: post_number,
                                 user_id: current_user.id,
                                 msecs: time)
        end
      end
    end

    total_changed = 0
    if timings.length > 0
      total_changed = Notification.mark_posts_read(current_user, topic_id, timings.map{|t| t[0]})
    end

    topic_time = max_time_per_post if topic_time > max_time_per_post

    TopicUser.update_last_read(current_user, topic_id, highest_seen, topic_time, opts)

    if total_changed > 0
      current_user.reload
      current_user.publish_notifications_state
    end
  end
end

# == Schema Information
#
# Table name: post_timings
#
#  topic_id    :integer          not null
#  post_number :integer          not null
#  user_id     :integer          not null
#  msecs       :integer          not null
#
# Indexes
#
#  index_post_timings_on_user_id  (user_id)
#  post_timings_summary           (topic_id,post_number)
#  post_timings_unique            (topic_id,post_number,user_id) UNIQUE
#
