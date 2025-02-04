# frozen_string_literal: true

class EnsureUniqueTagUserNotificationLevel < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      DELETE FROM tag_users
      USING tag_users AS dupe
      WHERE tag_users.id > dupe.id
      AND tag_users.user_id = dupe.user_id
      AND tag_users.tag_id = dupe.tag_id;
    SQL

    add_index :tag_users, %i[user_id tag_id], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
