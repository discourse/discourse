# frozen_string_literal: true

class RemoveNotificationLevelFromCategoryUserIndexes < ActiveRecord::Migration[5.2]
  def up
    execute <<SQL
DELETE FROM category_users cu USING category_users cu1
  WHERE cu.user_id = cu1.user_id AND
        cu.category_id = cu1.category_id AND
        cu.notification_level < cu1.notification_level
SQL

    remove_index :category_users, name: 'idx_category_users_u1'
    remove_index :category_users, name: 'idx_category_users_u2'

    add_index :category_users, [:user_id, :category_id],
        name: 'idx_category_users_user_id_category_id', unique: true
    add_index :category_users, [:category_id, :user_id],
        name: 'idx_category_users_category_id_user_id', unique: true
  end

  def down
    remove_index :category_users, name: 'idx_category_users_user_id_category_id'
    remove_index :category_users, name: 'idx_category_users_category_id_user_id'

    add_index :category_users, [:user_id, :category_id, :notification_level],
        name: 'idx_category_users_u1', unique: true
    add_index :category_users, [:category_id, :user_id, :notification_level],
        name: 'idx_category_users_u2', unique: true
  end
end
