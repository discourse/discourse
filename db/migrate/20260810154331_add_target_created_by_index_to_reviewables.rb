# frozen_string_literal: true

class AddTargetCreatedByIndexToReviewables < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_reviewables_on_target_created_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_reviewables_on_target_created_by_id
      ON reviewables (target_created_by_id)
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_reviewables_on_target_created_by_id
    SQL
  end
end
