# frozen_string_literal: true

class DeleteAnonymousUsersFromDirectoryItems < ActiveRecord::Migration[7.1]
  def up
    DB.exec(<<~SQL)
      DELETE FROM directory_items
      USING anonymous_users
      WHERE directory_items.user_id = anonymous_users.user_id
    SQL
  end

  def down
  end
end
