# frozen_string_literal: true

class MakePostReplyIdColumnReadOnly < ActiveRecord::Migration[6.0]
  def up
    Migration::ColumnDropper.mark_readonly(:post_replies, :reply_id)
    DB.exec("DROP FUNCTION IF EXISTS post_replies_sync_reply_id() CASCADE")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
