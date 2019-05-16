# frozen_string_literal: true

class MigrateReviewableFlaggedPosts < ActiveRecord::Migration[5.2]
  def up

    # for the migration we'll do 1.0 + trust_level and not take into account user flagging accuracy
    # It should be good enough for old flags whose scores are not as important as pending flags.
    execute(<<~SQL)
      INSERT INTO reviewables (
        type,
        status,
        topic_id,
        reviewable_by_moderator,
        category_id,
        payload,
        target_type,
        target_id,
        target_created_by_id,
        score,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT 'ReviewableFlaggedPost',
        CASE
          WHEN MAX(pa.agreed_at) IS NOT NULL THEN 1
          WHEN MAX(pa.disagreed_at) IS NOT NULL THEN 2
          WHEN MAX(pa.deferred_at) IS NOT NULL THEN 3
          WHEN MAX(pa.deleted_at) IS NOT NULL THEN 4
          ELSE 0
        END,
        t.id,
        true,
        t.category_id,
        json_build_object(),
        'Post',
        pa.post_id,
        p.user_id,
        0,
        MAX(pa.user_id),
        MIN(pa.created_at),
        MAX(pa.updated_at)
      FROM post_actions AS pa
      INNER JOIN posts AS p ON pa.post_id = p.id
      INNER JOIN topics AS t ON t.id = p.topic_id
      INNER JOIN post_action_types AS pat ON pat.id = pa.post_action_type_id
      WHERE pat.is_flag
        AND pat.name_key <> 'notify_user'
        AND p.user_id > 0
        AND p.deleted_at IS NULL
        AND t.deleted_at IS NULL
      GROUP BY pa.post_id,
        t.id,
        t.category_id,
        p.user_id
    SQL

    execute(<<~SQL)
      INSERT INTO reviewable_scores (
        reviewable_id,
        user_id,
        reviewable_score_type,
        status,
        score,
        meta_topic_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        pa.user_id,
        pa.post_action_type_id,
        CASE
          WHEN pa.agreed_at IS NOT NULL THEN 1
          WHEN pa.disagreed_at IS NOT NULL THEN 2
          WHEN pa.deferred_at IS NOT NULL THEN 3
          WHEN pa.deleted_at IS NOT NULL THEN 3
          ELSE 0
        END,
        1.0 +
        (CASE
          WHEN pau.moderator OR pau.admin THEN 5.0
          ELSE pau.trust_level
        END) +
        (CASE
          WHEN pa.staff_took_action THEN 5.0
          ELSE 0.0
        END),
        rp.topic_id,
        pa.created_at,
        pa.updated_at
      FROM post_actions AS pa
      INNER JOIN post_action_types AS pat ON pat.id = pa.post_action_type_id
      INNER JOIN users AS pau ON pa.user_id = pau.id
      INNER JOIN reviewables AS r ON pa.post_id = r.target_id
      LEFT OUTER JOIN posts AS rp ON rp.id = pa.related_post_id
      WHERE pat.is_flag
        AND r.type = 'ReviewableFlaggedPost'
    SQL

    execute(<<~SQL)
      UPDATE reviewables
      SET score = COALESCE((
        SELECT sum(score)
        FROM reviewable_scores AS rs
        WHERE rs.reviewable_id = reviewables.id
          AND rs.status = 0
      ), 0),
      potential_spam = EXISTS(
        SELECT 1
        FROM reviewable_scores AS rs
        WHERE rs.reviewable_id = reviewables.id
          AND rs.reviewable_score_type = 8
      )
    SQL
  end

  def down
    execute "DELETE FROM reviewables WHERE type = 'ReviewableFlaggedPost'"
    execute "DELETE FROM reviewable_scores"
  end
end
