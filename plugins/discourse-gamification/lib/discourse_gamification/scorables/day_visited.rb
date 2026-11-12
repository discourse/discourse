# frozen_string_literal: true

module DiscourseGamification
  class DayVisited < Scorable
    def self.query(leaderboard: nil)
      <<~SQL
        SELECT
          uv.user_id AS user_id,
          date_trunc('day', uv.visited_at) AS date,
          COUNT(*) * #{score_multiplier(leaderboard:)} AS points
        FROM
          user_visits AS uv
        WHERE
          uv.visited_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
