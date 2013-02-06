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

end
