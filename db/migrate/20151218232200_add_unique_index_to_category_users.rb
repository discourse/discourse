# frozen_string_literal: true

class AddUniqueIndexToCategoryUsers < ActiveRecord::Migration[4.2]
  def up
    execute <<SQL
DELETE FROM category_users cu USING category_users cu1
  WHERE cu.user_id = cu1.user_id AND
        cu.category_id = cu1.category_id AND
        cu.notification_level = cu1.notification_level AND
        cu.id < cu1.id
SQL

    add_index :category_users, [:user_id, :category_id, :notification_level],
        name: 'idx_category_users_u1', unique: true
    add_index :category_users, [:category_id, :user_id, :notification_level],
        name: 'idx_category_users_u2', unique: true
  end

  def down
    remove_index :category_users, name: 'idx_category_users_u1'
    remove_index :category_users, name: 'idx_category_users_u2'
  end
end
