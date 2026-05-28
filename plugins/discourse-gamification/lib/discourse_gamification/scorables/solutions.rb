# frozen_string_literal: true
module DiscourseGamification
  class Solutions < Scorable
    def self.enabled?(leaderboard: nil)
      defined?(DiscourseSolved) && SiteSetting.solved_enabled && super
    end

    def self.scorable_key
      "solution"
    end

    def self.category_filter(leaderboard: nil)
      return "" if scorable_category_list(leaderboard:).empty?

      <<~SQL
        AND topics.category_id IN (#{scorable_category_list(leaderboard:)})
      SQL
    end

    def self.query(leaderboard: nil)
      <<~SQL
        SELECT
          posts.user_id AS user_id,
          date_trunc('day', dsta.created_at) AS date,
          COUNT(dsst.topic_id) * #{score_multiplier(leaderboard:)} AS points
        FROM
          discourse_solved_solved_topics dsst
        INNER JOIN topics
          ON dsst.topic_id = topics.id
          #{category_filter(leaderboard:)}
        INNER JOIN discourse_solved_topic_answers dsta 
          ON dsta.solved_topic_id = dsst.id
        INNER JOIN posts 
          ON posts.id = dsta.answer_post_id
        WHERE
          posts.deleted_at IS NULL AND
          topics.deleted_at IS NULL AND
          topics.archetype <> 'private_message' AND
          posts.user_id != topics.user_id AND
          dsta.created_at >= :since
        GROUP BY
          1, 2
      SQL
    end
  end
end
