# frozen_string_literal: true

module ::DiscourseGamification
  class UserInvited < Scorable
    def self.score_multiplier
      SiteSetting.user_invited_score_value
    end

    def self.query
      <<~SQL
        SELECT
          inv.invited_by_id AS user_id,
          date_trunc('day', inv.created_at) AS date,
          SUM(inv.redemption_count * #{score_multiplier}) AS points
        FROM
          invites AS inv
        WHERE
          inv.created_at >= :since AND
          inv.redemption_count > 0
        GROUP BY
          1, 2
      SQL
    end
  end
end
