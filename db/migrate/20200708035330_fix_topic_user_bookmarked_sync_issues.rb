# frozen_string_literal: true

class FixTopicUserBookmarkedSyncIssues < ActiveRecord::Migration[6.0]
  def up
    sql = <<~SQL
      UPDATE topic_users SET bookmarked = true WHERE id IN (
        SELECT topic_users.id
        FROM topic_users
        INNER JOIN bookmarks ON bookmarks.user_id = topic_users.user_id AND
          bookmarks.topic_id = topic_users.topic_id
        WHERE NOT topic_users.bookmarked
      ) AND NOT bookmarked
    SQL
    DB.exec(sql)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
