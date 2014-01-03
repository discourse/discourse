class TopTopic < ActiveRecord::Base

  belongs_to :topic

  def self.periods
    @periods ||= [:yearly, :monthly, :weekly, :daily]
  end

  def self.sort_orders
    @sort_orders ||= [:posts, :views, :likes]
  end

  def self.refresh!
    transaction do
      # clean up the table
      exec_sql("DELETE FROM top_topics")
      # insert the list of all the visible topics
      exec_sql("INSERT INTO top_topics (topic_id)
                SELECT id
                FROM topics
                WHERE deleted_at IS NULL
                AND visible
                AND archetype <> :private_message
                AND NOT archived",
                private_message: Archetype::private_message)

      TopTopic.periods.each do |period|
        # update all the counter caches
        TopTopic.sort_orders.each do |sort|
          TopTopic.send("update_#{sort}_count_for", period)
        end
        # compute top score
        TopTopic.compute_top_score_for(period)
      end
    end
  end

  def self.update_posts_count_for(period)
    sql = "SELECT topic_id, GREATEST(COUNT(*), 1) AS count
           FROM posts p
           WHERE p.created_at >= :from
           AND p.deleted_at IS NULL
           AND NOT p.hidden
           AND post_type = #{Post.types[:regular]}
           AND user_id <> #{Discourse.system_user.id}
           GROUP BY topic_id"

    TopTopic.update_top_topics(period, "posts", sql)
  end

  def self.update_views_count_for(period)
    sql = "SELECT parent_id as topic_id, COUNT(*) AS count
           FROM views v
           WHERE v.viewed_at >= :from
           GROUP BY topic_id"

    TopTopic.update_top_topics(period, "views", sql)
  end

  def self.update_likes_count_for(period)
    sql = "SELECT topic_id, GREATEST(SUM(like_count), 1) AS count
           FROM posts p
           WHERE p.created_at >= :from
           AND p.deleted_at IS NULL
           AND NOT p.hidden
           GROUP BY topic_id"

    TopTopic.update_top_topics(period, "likes", sql)
  end

  def self.compute_top_score_for(period)
    # log(views) + (posts * likes)
    exec_sql("UPDATE top_topics
              SET #{period}_score = CASE #{period}_views_count
                                    WHEN 0 THEN 0
                                    ELSE log(#{period}_views_count) + (#{period}_posts_count * #{period}_likes_count)
                                    END")
  end

  def self.start_of(period)
    case period
      when :yearly  then 1.year.ago
      when :monthly then 1.month.ago
      when :weekly  then 1.week.ago
      when :daily   then 1.day.ago
    end
  end

  def self.update_top_topics(period, sort, inner_join)
    exec_sql("UPDATE top_topics
              SET #{period}_#{sort}_count = c.count
              FROM top_topics tt
              INNER JOIN (#{inner_join}) c ON tt.topic_id = c.topic_id
              WHERE tt.topic_id = top_topics.topic_id", from: start_of(period))
  end

end
