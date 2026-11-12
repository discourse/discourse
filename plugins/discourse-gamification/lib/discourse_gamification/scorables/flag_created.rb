# frozen_string_literal: true

module DiscourseGamification
  class FlagCreated < Scorable
    def self.query(leaderboard: nil)
      <<~SQL
        SELECT
          r.created_by_id AS user_id,
          date_trunc('day', r.created_at) AS date,
          COUNT(*) * #{score_multiplier(leaderboard:)} AS points
        FROM
          reviewables AS r
        WHERE
          created_at >= :since AND
          status = 1#{" "}
        GROUP BY
          1, 2
      SQL
    end
  end
end
