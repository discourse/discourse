# frozen_string_literal: true
class AddDiscardedUserIdIndexToDrafts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "idx_drafts_on_user_id_discarded"

  def up
    remove_index :drafts, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :drafts,
              :user_id,
              name: INDEX_NAME,
              where: "deleted_at IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :drafts, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
