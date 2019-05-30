# frozen_string_literal: true

class AddMissingUserDestroyerIndexes < ActiveRecord::Migration[5.2]
  def change
    # these indexes are required to make deletions of users fast
    add_index :user_actions, [:target_user_id], where: 'target_user_id IS NOT NULL'
    add_index :post_actions, [:user_id]
    add_index :user_uploads, [:user_id, :upload_id]
    add_index :user_auth_token_logs, [:user_id]
    add_index :topic_links, [:user_id]
  end
end
