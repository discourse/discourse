module Jobs
  class RetroRecentTimeRead < Jobs::Onceoff
    def execute_onceoff(args)
      # update past records by evenly distributing total time reading among each post read
      sql = <<~SQL
      UPDATE user_visits uv1
         SET time_read = (
        SELECT (
          uv1.posts_read
          / (SELECT CAST(sum(uv2.posts_read) AS FLOAT) FROM user_visits uv2 where uv2.user_id = uv1.user_id)
          * COALESCE((SELECT us.time_read FROM user_stats us WHERE us.user_id = uv1.user_id), 0)
        )
      )
      WHERE EXISTS (SELECT 1 FROM user_stats stats WHERE stats.user_id = uv1.user_id AND stats.posts_read_count > 0 LIMIT 1)
        AND EXISTS (SELECT 1 FROM user_visits visits WHERE visits.user_id = uv1.user_id AND visits.posts_read > 0 LIMIT 1)
      SQL

      DB.exec(sql)
    end
  end
end
