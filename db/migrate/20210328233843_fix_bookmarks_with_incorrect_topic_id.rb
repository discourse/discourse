# frozen_string_literal: true

class FixBookmarksWithIncorrectTopicId < ActiveRecord::Migration[6.0]
  def up
    result = DB.exec(<<~SQL)
      UPDATE bookmarks bm
      SET topic_id = subquery.correct_topic_id, updated_at = NOW()
      FROM (
        SELECT bookmarks.id AS bookmark_id, bookmarks.post_id, bookmarks.topic_id,
               posts.topic_id AS correct_topic_id
        FROM bookmarks
        INNER JOIN posts ON posts.id = bookmarks.post_id
        WHERE posts.topic_id != bookmarks.topic_id
      ) AS subquery
      WHERE bm.id = subquery.bookmark_id;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
