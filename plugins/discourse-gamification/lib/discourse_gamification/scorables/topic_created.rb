# frozen_string_literal: true

module ::DiscourseGamification
  class TopicCreated < Scorable
    def self.score_multiplier
      SiteSetting.topic_created_score_value
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
          t.user_id AS user_id,
          date_trunc('day', t.created_at) AS date,
          COUNT(*) * #{score_multiplier} AS points
        FROM
          topics AS t
        WHERE
          t.deleted_at IS NULL AND
          t.archetype <> 'private_message' AND
          t.created_at >= :since
          #{category_filter}
        GROUP BY
          1, 2
      SQL
    end
  end
end
