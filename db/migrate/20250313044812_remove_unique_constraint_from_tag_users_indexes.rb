# frozen_string_literal: true

class RemoveUniqueConstraintFromTagUsersIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    remove_index :tag_users, name: :idx_tag_users_ix1, algorithm: :concurrently, if_exists: true
    remove_index :tag_users, name: :idx_tag_users_ix2, algorithm: :concurrently, if_exists: true

    remove_index :tag_users,
                 %i[user_id tag_id notification_level],
                 algorithm: :concurrently,
                 if_exists: true

    remove_index :tag_users,
                 %i[tag_id user_id notification_level],
                 algorithm: :concurrently,
                 if_exists: true

    add_index :tag_users, %i[user_id tag_id notification_level], algorithm: :concurrently
    add_index :tag_users, %i[tag_id user_id notification_level], algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
