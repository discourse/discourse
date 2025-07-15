# frozen_string_literal: true

module ::DiscourseGamification
  class TimeRead < Scorable
    def self.score_multiplier
      SiteSetting.time_read_score_value
    end

    def self.query
      <<~SQL
        SELECT
          uv.user_id AS user_id,
          date_trunc('day', uv.visited_at) AS date,
          SUM(uv.time_read) / 3600 * #{score_multiplier} AS points
        FROM
          user_visits AS uv
        WHERE
          uv.visited_at >= :since AND
          uv.time_read >= 60
        GROUP BY
          1, 2
      SQL
    end
  end
end
