# frozen_string_literal: true
module DiscourseGamification
  class ReactionReceived < Scorable
    def self.enabled?(leaderboard: nil)
      defined?(DiscourseReactions) && SiteSetting.discourse_reactions_enabled && super
    end

    def self.category_filter(leaderboard: nil)
      return "" if scorable_category_list(leaderboard:).empty?

      <<~SQL
        AND t.category_id IN (#{scorable_category_list(leaderboard:)})
      SQL
    end

    def self.query(leaderboard: nil)
      <<~SQL
        SELECT
          p.user_id AS user_id,
          date_trunc('day', reactions.created_at) AS date,
          COUNT(*) * #{score_multiplier(leaderboard:)} AS points
        FROM
        discourse_reactions_reaction_users AS reactions
        INNER JOIN posts AS p
          ON p.id = reactions.post_id
        INNER JOIN topics AS t
          ON t.id = p.topic_id
          #{category_filter(leaderboard:)}
        WHERE
          p.deleted_at IS NULL AND
          t.archetype <> 'private_message' AND
          p.wiki IS FALSE AND
          reactions.created_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
