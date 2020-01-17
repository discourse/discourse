# frozen_string_literal: true

class AddTriggerToSyncPostReplies < ActiveRecord::Migration[6.0]
  def up
    # we don't want this column to be readonly yet
    Migration::ColumnDropper.drop_readonly(:post_replies, :reply_id)

    DB.exec <<~SQL
      CREATE OR REPLACE FUNCTION post_replies_sync_reply_id()
      RETURNS trigger AS $rcr$
      BEGIN
        NEW.reply_post_id := NEW.reply_id;
        RETURN NEW;
      END
      $rcr$ LANGUAGE plpgsql;
    SQL

    DB.exec <<~SQL
      CREATE TRIGGER post_replies_reply_id_sync
      BEFORE INSERT OR UPDATE OF reply_id ON post_replies
      FOR EACH ROW
      WHEN (NEW.reply_id IS NOT NULL)
      EXECUTE PROCEDURE post_replies_sync_reply_id();
    SQL

    # one more sync because we could be missing some data from the time between the
    # "20200116140132_rename_reply_id_column" migration and now
    execute <<~SQL
      UPDATE post_replies
      SET reply_post_id = reply_id
      WHERE reply_post_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
