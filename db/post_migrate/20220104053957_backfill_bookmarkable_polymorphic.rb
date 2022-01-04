# frozen_string_literal: true

class BackfillBookmarkablePolymorphic < ActiveRecord::Migration[6.1]
  def up
    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = post_id, bookmarkable_type = 'Post'
      WHERE NOT for_topic
    SQL
    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = posts.topic_id, bookmarkable_type = 'Topic'
      FROM posts
      WHERE for_topic AND posts.id = bookmarks.post_id
    SQL
    change_column_null :bookmarks, :bookmarkable_id, false
    change_column_null :bookmarks, :bookmarkable_type, false
  end

  def down
    change_column_null :bookmarks, :bookmarkable_id, true
    change_column_null :bookmarks, :bookmarkable_type, true
  end
end
