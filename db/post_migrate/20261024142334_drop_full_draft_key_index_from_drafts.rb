# frozen_string_literal: true
class DropFullDraftKeyIndexFromDrafts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_drafts_on_user_id_and_draft_key"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
