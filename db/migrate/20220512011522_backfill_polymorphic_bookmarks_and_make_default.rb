# frozen_string_literal: true

class BackfillPolymorphicBookmarksAndMakeDefault < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE site_settings
      SET value = 't'
      WHERE name = 'use_polymorphic_bookmarks'
    SQL

    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = post_id, bookmarkable_type = 'Post'
      WHERE NOT bookmarks.for_topic AND bookmarkable_id IS NULL
    SQL

    DB.exec(<<~SQL)
      DELETE FROM bookmarks
      WHERE id NOT IN (
        SELECT MIN(bookmarks.id)
        FROM bookmarks
        INNER JOIN posts ON bookmarks.post_id = posts.id
        WHERE bookmarks.for_topic
        GROUP BY (bookmarks.user_id, posts.topic_id)
      ) AND bookmarks.for_topic
    SQL

    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = posts.topic_id, bookmarkable_type = 'Topic'
      FROM posts
      WHERE bookmarks.for_topic AND posts.id = bookmarks.post_id AND bookmarkable_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
