# frozen_string_literal: true

class FixTopicUserBookmarkedSyncIssuesAgain < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    DB.exec(<<~SQL)
        UPDATE topic_users SET bookmarked = true
        FROM bookmarks AS b
        WHERE NOT topic_users.bookmarked AND topic_users.topic_id = b.topic_id AND topic_users.user_id = b.user_id
      SQL

    DB.exec(<<~SQL)
        UPDATE topic_users SET bookmarked = false
        WHERE topic_users.bookmarked AND (SELECT COUNT(*) FROM bookmarks WHERE topic_id = topic_users.topic_id AND user_id = topic_users.user_id) = 0
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
