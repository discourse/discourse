# frozen_string_literal: true

class AddTriggerForPolymorphicBookmarkColumnsToSyncData < ActiveRecord::Migration[6.1]
  def up
    DB.exec <<~SQL
      CREATE OR REPLACE FUNCTION sync_bookmarks_polymorphic_column_data()
      RETURNS TRIGGER
      LANGUAGE PLPGSQL AS $rcr$
      BEGIN
        IF NEW.for_topic
        THEN
          NEW.bookmarkable_id = (SELECT topic_id FROM posts WHERE posts.id = NEW.post_id);
          NEW.bookmarkable_type = 'Topic';
        ELSE
          NEW.bookmarkable_id = NEW.post_id;
          NEW.bookmarkable_type = 'Post';
        END IF;
        RETURN NEW;
      END
      $rcr$;
    SQL

    DB.exec <<~SQL
      CREATE TRIGGER bookmarks_polymorphic_data_sync
      BEFORE INSERT OR UPDATE OF post_id, for_topic ON bookmarks
      FOR EACH ROW
      EXECUTE FUNCTION sync_bookmarks_polymorphic_column_data();
    SQL

    # sync data that already exists in the table
    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = post_id, bookmarkable_type = 'Post'
      WHERE NOT bookmarks.for_topic
    SQL
    DB.exec(<<~SQL)
      UPDATE bookmarks
      SET bookmarkable_id = posts.topic_id, bookmarkable_type = 'Topic'
      FROM posts
      WHERE bookmarks.for_topic AND posts.id = bookmarks.post_id
    SQL
  end

  def down
    DB.exec("DROP TRIGGER IF EXISTS bookmarks_polymorphic_data_sync")
    DB.exec("DROP FUNCTION IF EXISTS sync_bookmarks_polymorphic_column_data")
  end
end
