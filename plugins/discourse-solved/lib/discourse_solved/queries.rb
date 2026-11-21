# frozen_string_literal: true

module DiscourseSolved
  module Queries
    def self.solved_badge_query(min_count)
      <<~SQL
        SELECT p.user_id, MAX(dsta.created_at) AS granted_at
        FROM discourse_solved_solved_topics dsst
             JOIN discourse_solved_topic_answers dsta ON dsta.solved_topic_id = dsst.id
             JOIN badge_posts p ON dsta.answer_post_id = p.id
             JOIN topics t ON p.topic_id = t.id
        WHERE p.user_id <> t.user_id -- ignore topics solved by OP
          AND (:backfill OR p.id IN (:post_ids))
        GROUP BY p.user_id
        HAVING COUNT(*) >= #{min_count.to_i}
      SQL
    end

    def self.solved_count(user_id)
      DiscourseSolved::SolvedTopic
        .joins(topic_answers: :post)
        .joins(:topic)
        .where(posts: { user_id: user_id, deleted_at: nil })
        .where(topics: { archetype: Archetype.default, deleted_at: nil })
        .count
    end
  end
end
