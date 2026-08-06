# frozen_string_literal: true

class AddTargetCreatedByIndexToReviewables < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX IF EXISTS idx_reviewables_flagged_by_target_created_by
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY idx_reviewables_flagged_by_target_created_by
        ON reviewables(target_created_by_id)
        WHERE type = 'ReviewableFlaggedPost'
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS idx_reviewables_flagged_by_target_created_by
    SQL
  end
end
