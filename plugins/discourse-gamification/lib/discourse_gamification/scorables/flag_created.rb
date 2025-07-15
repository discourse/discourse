# frozen_string_literal: true

module ::DiscourseGamification
  class FlagCreated < Scorable
    def self.score_multiplier
      SiteSetting.flag_created_score_value
    end

    def self.query
      <<~SQL
        SELECT
          r.created_by_id AS user_id,
          date_trunc('day', r.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
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
