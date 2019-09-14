# frozen_string_literal: true

module Jobs
  class FixPostsRead < ::Jobs::Onceoff
    def execute_onceoff(args)
      # Skipping to the last post in a topic used to count all posts in the topic
      # as read in user stats. Cap the posts read count to 50 * topics_entered.

      sql = <<~SQL
UPDATE user_stats
   SET posts_read_count = topics_entered * 50
 WHERE user_id IN (
   SELECT us2.user_id
     FROM user_stats us2
    WHERE us2.topics_entered > 0
      AND us2.posts_read_count / us2.topics_entered > 50
 )
      SQL

      DB.exec(sql)
    end
  end
end
