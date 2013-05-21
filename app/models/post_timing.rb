class PostTiming < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  validates_presence_of :post_number
  validates_presence_of :msecs


  # Increases a timer if a row exists, otherwise create it
  def self.record_timing(args)
    rows = exec_sql_row_count("UPDATE post_timings
                               SET msecs = msecs + :msecs
                               WHERE topic_id = :topic_id
                                AND user_id = :user_id
                                AND post_number = :post_number",
                                args)

    if rows == 0
      Post.update_all 'reads = reads + 1', ['topic_id = :topic_id and post_number = :post_number', args]
      exec_sql("INSERT INTO post_timings (topic_id, user_id, post_number, msecs)
                  SELECT :topic_id, :user_id, :post_number, :msecs
                  WHERE NOT EXISTS(SELECT 1 FROM post_timings
                                   WHERE topic_id = :topic_id
                                    AND user_id = :user_id
                                    AND post_number = :post_number)",
               args)

    end
  end


  def self.destroy_for(user_id, topic_id)
    PostTiming.transaction do
      PostTiming.delete_all(['user_id = ? and topic_id = ?', user_id, topic_id])
      TopicUser.delete_all(['user_id = ? and topic_id = ?', user_id, topic_id])
    end
  end


  def self.process_timings(current_user, topic_id, topic_time, timings)
    current_user.update_time_read!

    highest_seen = 1
    timings.each do |post_number, time|
      if post_number >= 0
        PostTiming.record_timing(topic_id: topic_id,
                                 post_number: post_number,
                                 user_id: current_user.id,
                                 msecs: time)

        highest_seen = post_number.to_i > highest_seen ?
                       post_number.to_i : highest_seen
      end
    end

    total_changed = 0
    if timings.length > 0
      total_changed = Notification.mark_posts_read(current_user, topic_id, timings.map{|t| t[0]})
    end

    TopicUser.update_last_read(current_user, topic_id, highest_seen, topic_time)

    if total_changed > 0
      current_user.reload
      current_user.publish_notifications_state
    end
  end
end
