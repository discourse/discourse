# frozen_string_literal: true

class IndexAllAnonymousUsersByMasterUserId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_anonymous_users_all_shadows_by_master"

  def up
    remove_index :anonymous_users, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :anonymous_users, :master_user_id, name: INDEX_NAME, algorithm: :concurrently
  end

  def down
    remove_index :anonymous_users, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
