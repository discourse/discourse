# frozen_string_literal: true

class AddIndexToLastSeenAtOnCategoryUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    if !index_exists?(:category_users, [:user_id, :last_seen_at])
      add_index :category_users, [:user_id, :last_seen_at], algorithm: :concurrently
    end
  end

  def down
    remove_index :category_users, [:user_id, :last_seen_at]
  end
end
