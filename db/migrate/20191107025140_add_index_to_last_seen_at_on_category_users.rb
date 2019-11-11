# frozen_string_literal: true

class AddIndexToLastSeenAtOnCategoryUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    if !index_exists?(:category_users, [:user_id, :last_seen_at])
      add_index :category_users, [:user_id, :last_seen_at], algorithm: :concurrently
    end

    remove_index :category_users, name: 'idx_category_users_user_id_category_id'
    remove_index :category_users, name: 'idx_category_users_category_id_user_id'

    add_index :category_users, [:user_id, :category_id],
        name: 'idx_category_users_user_id_category_id', unique: false
    add_index :category_users, [:category_id, :user_id],
        name: 'idx_category_users_category_id_user_id', unique: false
  end

  def down
    remove_index :category_users, [:user_id, :last_seen_at]

    remove_index :category_users, name: 'idx_category_users_user_id_category_id'
    remove_index :category_users, name: 'idx_category_users_category_id_user_id'

    add_index :category_users, [:user_id, :category_id],
        name: 'idx_category_users_user_id_category_id', unique: true
    add_index :category_users, [:category_id, :user_id],
        name: 'idx_category_users_category_id_user_id', unique: true
  end
end
