# frozen_string_literal: true

class ResetReviewFieldsOnRevivedFlags < ActiveRecord::Migration[8.0]
  def up
    # A flag reviewed before it was created is a trashed flag that a re-flag revived with its
    # old review intact. It never counts as active, so acting on its pending reviewable has no
    # effect. Reviewable status 0 = pending. Flag types 3, 4, 7, 8 mirror idx_unique_flags, which
    # a cleared flag must not collide with.
    execute <<~SQL
      UPDATE post_actions pa
      SET agreed_at = NULL,
        agreed_by_id = NULL,
        deferred_at = NULL,
        deferred_by_id = NULL,
        disagreed_at = NULL,
        disagreed_by_id = NULL
      WHERE pa.deleted_at IS NULL
        AND LEAST(pa.agreed_at, pa.deferred_at, pa.disagreed_at) < pa.created_at
        AND EXISTS (
          SELECT 1
          FROM reviewables r
          WHERE r.type = 'ReviewableFlaggedPost'
            AND r.target_type = 'Post'
            AND r.target_id = pa.post_id
            AND r.status = 0
        )
        AND NOT EXISTS (
          SELECT 1
          FROM post_actions other
          WHERE other.id <> pa.id
            AND other.user_id = pa.user_id
            AND other.post_id = pa.post_id
            AND other.targets_topic = pa.targets_topic
            AND other.deleted_at IS NULL
            AND (
              other.post_action_type_id = pa.post_action_type_id
              OR (
                other.post_action_type_id IN (3, 4, 7, 8)
                AND pa.post_action_type_id IN (3, 4, 7, 8)
              )
            )
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
