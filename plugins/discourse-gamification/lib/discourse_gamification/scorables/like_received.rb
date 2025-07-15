# frozen_string_literal: true
module ::DiscourseGamification
  class LikeReceived < Scorable
    def self.score_multiplier
      SiteSetting.like_received_score_value
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
          p.user_id AS user_id,
          date_trunc('day', pa.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
        FROM
          post_actions AS pa
        INNER JOIN posts AS p
          ON p.id = pa.post_id
        INNER JOIN topics AS t
          ON t.id = p.topic_id
          #{category_filter}
        WHERE
          p.deleted_at IS NULL AND
          t.archetype <> 'private_message' AND
          p.wiki IS FALSE AND
          post_action_type_id = 2 AND
          pa.created_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
