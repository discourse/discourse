# frozen_string_literal: true

class BackfillPolymorphicBookmarks < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = post_id, bookmarkable_type = 'Post'
      WHERE NOT bookmarks.for_topic AND bookmarkable_id IS NULL
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
