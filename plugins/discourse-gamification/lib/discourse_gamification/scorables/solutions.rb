# frozen_string_literal: true
module ::DiscourseGamification
  class Solutions < Scorable
    def self.enabled?
      defined?(DiscourseSolved) && SiteSetting.solved_enabled && super
    end

    def self.score_multiplier
      SiteSetting.solution_score_value
    end

    def self.category_filter
      return "" if scorable_category_list.empty?

      <<~SQL
        AND topics.category_id IN (#{scorable_category_list})
      SQL
    end

    def self.query
      <<~SQL
        SELECT
          posts.user_id AS user_id,
          date_trunc('day', dsst.updated_at) AS date,
          COUNT(dsst.topic_id) * #{score_multiplier} AS points
        FROM
          discourse_solved_solved_topics dsst
        INNER JOIN topics
          ON dsst.topic_id = topics.id
          #{category_filter}
        INNER JOIN posts
          ON posts.id = dsst.answer_post_id
        WHERE
          posts.deleted_at IS NULL AND
          topics.deleted_at IS NULL AND
          topics.archetype <> 'private_message' AND
          posts.user_id != topics.user_id AND
          dsst.updated_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
