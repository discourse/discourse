# frozen_string_literal: true
module ::DiscourseGamification
  class ReactionGiven < Scorable
    def self.enabled?
      defined?(::DiscourseReactions) && SiteSetting.discourse_reactions_enabled &&
        score_multiplier > 0
    end

    def self.score_multiplier
      SiteSetting.reaction_given_score_value
    end

    def self.category_filter
      return "" if scorable_category_list.empty?

      <<~SQL
        AND t.category_id IN (#{scorable_category_list})
      SQL
    end

    def self.query
      <<~SQL
        SELECT
          reactions.user_id AS user_id,
          date_trunc('day', reactions.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
        FROM
          discourse_reactions_reaction_users AS reactions
        INNER JOIN posts AS p
          ON p.id = reactions.post_id
        INNER JOIN topics AS t
          ON t.id = p.topic_id
          #{category_filter}
        WHERE
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          p.wiki IS FALSE AND
          reactions.created_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
