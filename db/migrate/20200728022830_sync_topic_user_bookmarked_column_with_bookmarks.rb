# frozen_string_literal: true

class SyncTopicUserBookmarkedColumnWithBookmarks < ActiveRecord::Migration[6.0]
  def up
    should_be_bookmarked_sql = <<~SQL
      UPDATE topic_users SET bookmarked = true WHERE id IN (
        SELECT topic_users.id
        FROM topic_users
        INNER JOIN bookmarks ON bookmarks.user_id = topic_users.user_id AND
          bookmarks.topic_id = topic_users.topic_id
        WHERE NOT topic_users.bookmarked
      ) AND NOT bookmarked
    SQL
    DB.exec(should_be_bookmarked_sql)

    # post_action_type_id 1 is bookmark
    should_not_be_bookmarked_sql = <<~SQL
    UPDATE topic_users SET bookmarked = FALSE WHERE ID IN (
      SELECT DISTINCT topic_users.id FROM topic_users
      LEFT JOIN bookmarks ON bookmarks.topic_id = topic_users.topic_id AND bookmarks.user_id = topic_users.user_id
      LEFT JOIN post_actions ON post_actions.user_id = topic_users.user_id AND post_actions.post_action_type_id = 1 AND post_actions.post_id IN (SELECT id FROM posts WHERE posts.topic_id = topic_users.topic_id)
      WHERE topic_users.bookmarked = true AND (bookmarks.id IS NULL AND post_actions.id IS NULL))
    SQL
    DB.exec(should_not_be_bookmarked_sql)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
