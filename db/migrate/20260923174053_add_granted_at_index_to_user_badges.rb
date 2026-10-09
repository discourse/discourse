# frozen_string_literal: true

class AddGrantedAtIndexToUserBadges < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "idx_user_badges_granted_at"

  def up
    remove_index :user_badges, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :user_badges,
              :granted_at,
              name: INDEX_NAME,
              order: {
                granted_at: :desc,
              },
              algorithm: :concurrently
  end

  def down
    remove_index :user_badges, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
