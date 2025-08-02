# frozen_string_literal: true

class FixTopicUsersBookmarkedColumnThatShouldBeFalse < ActiveRecord::Migration[6.0]
  def up
    # post_action_type_id 1 is bookmark
    sql = <<~SQL
    UPDATE topic_users SET bookmarked = FALSE WHERE ID IN (
      SELECT DISTINCT topic_users.id FROM topic_users
      LEFT JOIN bookmarks ON bookmarks.topic_id = topic_users.topic_id AND bookmarks.user_id = topic_users.user_id
      LEFT JOIN post_actions ON post_actions.user_id = topic_users.user_id AND post_actions.post_action_type_id = 1 AND post_actions.post_id IN (SELECT id FROM posts WHERE posts.topic_id = topic_users.topic_id)
      WHERE topic_users.bookmarked = true AND (bookmarks.id IS NULL AND post_actions.id IS NULL))
    SQL
    DB.exec(sql)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
