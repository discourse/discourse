# frozen_string_literal: true

module DiscourseTopicVoting
  module BadgeQueries
    def self.for_threshold(count)
      <<~SQL
        SELECT post_id, user_id, granted_at
        FROM (
          SELECT
            p.id AS post_id,
            t.user_id,
            v.created_at AS granted_at,
            ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY v.created_at) AS rn
          FROM topic_voting_votes v
          JOIN topics t ON t.id = v.topic_id
          JOIN badge_posts p ON p.topic_id = t.id AND p.post_number = 1
          WHERE v.user_id <> t.user_id
            AND (:backfill OR p.id IN (:post_ids))
        ) q
        WHERE rn = #{count}
      SQL
    end
  end
end
