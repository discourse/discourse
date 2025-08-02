# frozen_string_literal: true

module ::DiscourseGamification
  class PostCreated < Scorable
    def self.score_multiplier
      SiteSetting.post_created_score_value
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
          date_trunc('day', p.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
        FROM
          posts AS p
        INNER JOIN topics AS t
          ON t.id = p.topic_id
          #{category_filter}
        WHERE
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          t.archetype <> 'private_message' AND
          p.post_number <> 1 AND
          p.post_type = 1 AND
          p.wiki IS FALSE AND
          p.hidden IS FALSE AND
          p.created_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
