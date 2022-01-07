# frozen_string_literal: true

class AddTriggerForPolymorphicBookmarkColumnsToSyncData < ActiveRecord::Migration[6.1]
  def up
    # Note from Martin:
    #
    # Addition to the note below, we don't want to delete this migration but
    # we can stop it from creating things we are going to delete anyway.
    #
    # DB.exec <<~SQL
    #   CREATE OR REPLACE FUNCTION sync_bookmarks_polymorphic_column_data()
    #   RETURNS TRIGGER
    #   LANGUAGE PLPGSQL AS $rcr$
    #   BEGIN
    #     IF NEW.for_topic
    #     THEN
    #       NEW.bookmarkable_id = (SELECT topic_id FROM posts WHERE posts.id = NEW.post_id);
    #       NEW.bookmarkable_type = 'Topic';
    #     ELSE
    #       NEW.bookmarkable_id = NEW.post_id;
    #       NEW.bookmarkable_type = 'Post';
    #     END IF;
    #     RETURN NEW;
    #   END
    #   $rcr$;
    # SQL

    # DB.exec <<~SQL
    #   CREATE TRIGGER bookmarks_polymorphic_data_sync
    #   BEFORE INSERT OR UPDATE OF post_id, for_topic ON bookmarks
    #   FOR EACH ROW
    #   EXECUTE FUNCTION sync_bookmarks_polymorphic_column_data();
    # SQL

    # sync data that already exists in the table
    #
    # Note from Martin:
    #
    # We cannot remove this migration but we also don't want to do this
    # backfilling until this refactor is complete, removing the backfilling
    # for now as DropBookmarkPolymorphicTrigger removes the trigger used
    # here.
    #
    # DB.exec(<<~SQL)
    #   UPDATE bookmarks
    #   SET bookmarkable_id = post_id, bookmarkable_type = 'Post'
    #   WHERE NOT bookmarks.for_topic
    # SQL
    # DB.exec(<<~SQL)
    #   UPDATE bookmarks
    #   SET bookmarkable_id = posts.topic_id, bookmarkable_type = 'Topic'
    #   FROM posts
    #   WHERE bookmarks.for_topic AND posts.id = bookmarks.post_id
    # SQL
  end

  def down
    DB.exec("DROP FUNCTION IF EXISTS sync_bookmarks_polymorphic_column_data CASCADE")
  end
end
