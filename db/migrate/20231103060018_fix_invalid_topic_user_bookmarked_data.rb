# frozen_string_literal: true

class FixInvalidTopicUserBookmarkedData < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE topic_users
      SET bookmarked = true
      WHERE id IN (
        SELECT
          topic_users.id
        FROM topic_users
        INNER JOIN bookmarks ON bookmarks.user_id = topic_users.user_id
        WHERE bookmarkable_type = 'Topic'
          AND bookmarks.bookmarkable_id = topic_users.topic_id
          AND topic_users.bookmarked = false
      ) AND topic_users.bookmarked = false
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
