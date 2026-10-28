# frozen_string_literal: true
class AddUserIdIndexToDrafts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "idx_drafts_on_user_id"

  def up
    remove_index :drafts, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :drafts, :user_id, name: INDEX_NAME, algorithm: :concurrently
  end

  def down
    remove_index :drafts, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
