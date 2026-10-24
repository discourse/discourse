# frozen_string_literal: true
class AddLiveDraftKeyIndexToDrafts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_drafts_on_user_id_and_draft_key_live"
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY idx_drafts_on_user_id_and_draft_key_live
      ON drafts (user_id, draft_key)
      WHERE deleted_at IS NULL
    SQL

    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_drafts_on_deleted_at"
    execute <<~SQL
      CREATE INDEX CONCURRENTLY idx_drafts_on_deleted_at
      ON drafts (deleted_at)
      WHERE deleted_at IS NOT NULL
    SQL

    # keeps user_id-only lookups (user deletion, merges) indexed once the full unique index is dropped
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_drafts_on_user_id"
    execute "CREATE INDEX CONCURRENTLY idx_drafts_on_user_id ON drafts (user_id)"
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_drafts_on_user_id_and_draft_key_live"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_drafts_on_deleted_at"
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_drafts_on_user_id"
  end
end
