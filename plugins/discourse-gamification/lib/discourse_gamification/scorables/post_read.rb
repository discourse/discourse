# frozen_string_literal: true

module ::DiscourseGamification
  class PostRead < Scorable
    def self.score_multiplier
      SiteSetting.post_read_score_value
    end

    def self.query
      <<~SQL
        SELECT
          uv.user_id AS user_id,
          date_trunc('day', uv.visited_at) AS date,
          SUM(uv.posts_read) / 100 * #{score_multiplier} AS points
        FROM
          user_visits AS uv
        WHERE
          uv.visited_at >= :since AND
          uv.posts_read >= 5
        GROUP BY
          1, 2
      SQL
    end
  end
end
