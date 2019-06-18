# frozen_string_literal: true

class MigrateFlagHistory < ActiveRecord::Migration[5.2]
  def up

    # Migrate Created History
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        0,
        0,
        r.created_by_id,
        r.created_at,
        r.created_at
      FROM reviewables AS r
      WHERE r.type = 'ReviewableFlaggedPost'
        AND (
          NOT EXISTS(
            SELECT 1
            FROM reviewable_histories AS rh
            WHERE rh.reviewable_id = r.id
              AND rh.reviewable_history_type = 0
          )
        )
    SQL

    # Approved
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        1,
        pa.agreed_by_id,
        pa.agreed_at,
        pa.agreed_at
      FROM reviewables AS r
      INNER JOIN post_actions AS pa ON pa.post_id = r.target_id
      WHERE r.type = 'ReviewableFlaggedPost'
        AND pa.agreed_at IS NOT NULL
        AND pa.agreed_by_id IS NOT NULL
    SQL

    # Rejected
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        2,
        pa.disagreed_by_id,
        pa.disagreed_at,
        pa.disagreed_at
      FROM reviewables AS r
      INNER JOIN post_actions AS pa ON pa.post_id = r.target_id
      WHERE r.type = 'ReviewableFlaggedPost'
        AND pa.disagreed_at IS NOT NULL
        AND pa.disagreed_by_id IS NOT NULL
    SQL

    # Ignored
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        3,
        pa.deferred_by_id,
        pa.deferred_at,
        pa.deferred_at
      FROM reviewables AS r
      INNER JOIN post_actions AS pa ON pa.post_id = r.target_id
      WHERE r.type = 'ReviewableFlaggedPost'
        AND pa.deferred_at IS NOT NULL
        AND pa.deferred_by_id IS NOT NULL
    SQL

    # Deleted
    execute(<<~SQL)
      INSERT INTO reviewable_histories (
        reviewable_id,
        reviewable_history_type,
        status,
        created_by_id,
        created_at,
        updated_at
      )
      SELECT r.id,
        1,
        4,
        pa.deleted_by_id,
        pa.deleted_at,
        pa.deleted_at
      FROM reviewables AS r
      INNER JOIN post_actions AS pa ON pa.post_id = r.target_id
      WHERE r.type = 'ReviewableFlaggedPost'
        AND pa.deleted_at IS NOT NULL
        AND pa.deleted_by_id IS NOT NULL
    SQL
  end

  def down
    execute(<<~SQL)
      DELETE FROM reviewable_histories
      WHERE reviewable_id IN (SELECT id FROM reviewables WHERE type = 'ReviewableFlaggedPost')
    SQL
  end
end
