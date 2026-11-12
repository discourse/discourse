# frozen_string_literal: true
class AddUserIdToUserActionsActionTypeCreatedAtIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX = "index_user_actions_on_action_type_and_created_at"

  # Widen the existing index with user_id so the daily engaged users report can
  # satisfy its per-day distinct-user query with an index-only scan.
  def up
    remove_index :user_actions, name: INDEX, algorithm: :concurrently, if_exists: true
    add_index :user_actions,
              %i[action_type created_at user_id],
              name: INDEX,
              algorithm: :concurrently
  end

  def down
    remove_index :user_actions, name: INDEX, algorithm: :concurrently, if_exists: true
    add_index :user_actions, %i[action_type created_at], name: INDEX, algorithm: :concurrently
  end
end
