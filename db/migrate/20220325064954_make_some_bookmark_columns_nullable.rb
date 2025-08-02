# frozen_string_literal: true

class MakeSomeBookmarkColumnsNullable < ActiveRecord::Migration[6.1]
  def up
    change_column_null :bookmarks, :post_id, true
    execute "ALTER TABLE bookmarks ADD CONSTRAINT enforce_post_id_or_bookmarkable CHECK (
      (post_id IS NOT NULL) OR (bookmarkable_id IS NOT NULL AND bookmarkable_type IS NOT NULL)
    )"
  end

  def down
    DB.exec("UPDATE bookmarks SET post_id = bookmarkable_id WHERE bookmarkable_type = 'Post'")
    DB.exec(
      "UPDATE bookmarks SET post_id = (SELECT id FROM posts WHERE topic_id = bookmarkable_id AND post_number = 1), for_topic = TRUE WHERE bookmarkable_type = 'Topic'",
    )
    change_column_null :bookmarks, :post_id, false
    execute "ALTER TABLE bookmarks DROP CONSTRAINT enforce_post_id_or_bookmarkable"
  end
end
