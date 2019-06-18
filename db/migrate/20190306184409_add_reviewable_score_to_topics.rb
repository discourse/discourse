# frozen_string_literal: true

class AddReviewableScoreToTopics < ActiveRecord::Migration[5.2]
  def up
    add_column :topics, :reviewable_score, :float, null: false, default: 0

    execute(<<~SQL)
      UPDATE topics
      SET reviewable_score = sums.score
      FROM (
         SELECT SUM(r.score) AS score,
           r.topic_id
         FROM reviewables AS r
         WHERE r.status = 0
         GROUP BY r.topic_id
      ) AS sums
      WHERE sums.topic_id = topics.id
    SQL
  end

  def down
    remove_column :topics, :reviewable_score
  end
end
