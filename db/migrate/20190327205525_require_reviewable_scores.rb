# frozen_string_literal: true

class RequireReviewableScores < ActiveRecord::Migration[5.2]
  def up
    min_score = DB.query_single("SELECT value FROM site_settings WHERE name = 'min_score_default_visibility'")[0].to_f
    min_score = 1.0 if (min_score < 1.0)

    execute(<<~SQL)
      INSERT INTO reviewable_scores (
        reviewable_id,
        user_id,
        reviewable_score_type,
        score,
        status,
        created_at,
        updated_at
      )
      SELECT r.id,
        -1,
        9,
        #{min_score},
        r.status,
        r.created_at,
        r.created_at
      FROM reviewables AS r
      WHERE r.type IN ('ReviewableQueuedPost', 'ReviewableUser')
    SQL

    execute(<<~SQL)
      UPDATE reviewables SET score = (
        SELECT COALESCE(SUM(score), 0)
        FROM reviewable_scores
        WHERE reviewable_scores.reviewable_id = reviewables.id
      )
    SQL
  end

  def down
    execute(<<~SQL)
      DELETE FROM reviewable_scores WHERE reviewable_id IN (
        SELECT id FROM reviewables WHERE type IN ('ReviewableQueuedPost', 'ReviewableUser')
      )
    SQL
  end
end
