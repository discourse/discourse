# frozen_string_literal: true
class AddLiveDraftKeyIndexToDrafts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "idx_drafts_on_user_id_and_draft_key_live"

  def up
    remove_index :drafts, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :drafts,
              %i[user_id draft_key],
              name: INDEX_NAME,
              unique: true,
              where: "deleted_at IS NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :drafts, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
