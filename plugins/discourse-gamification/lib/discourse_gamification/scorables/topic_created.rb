# frozen_string_literal: true

module DiscourseGamification
  class TopicCreated < Scorable
    def self.category_filter(leaderboard: nil)
      return "" if scorable_category_list(leaderboard:).empty?

      <<~SQL
        AND t.category_id IN (#{scorable_category_list(leaderboard:)})
      SQL
    end

    def self.query(leaderboard: nil)
      <<~SQL
        SELECT
          t.user_id AS user_id,
          date_trunc('day', t.created_at) AS date,
          COUNT(*) * #{score_multiplier(leaderboard:)} AS points
        FROM
          topics AS t
        WHERE
          t.deleted_at IS NULL AND
          t.archetype <> 'private_message' AND
          t.created_at >= :since
          #{category_filter(leaderboard:)}
        GROUP BY
          1, 2
      SQL
    end
  end
end
