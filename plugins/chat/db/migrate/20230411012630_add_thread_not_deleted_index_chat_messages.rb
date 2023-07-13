# frozen_string_literal: true

class AddThreadNotDeletedIndexChatMessages < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    execute <<~SQL
      DROP INDEX IF EXISTS idx_chat_messages_by_thread_id_not_deleted
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      idx_chat_messages_by_thread_id_not_deleted
      ON chat_messages (thread_id)
      WHERE deleted_at IS NULL
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS idx_chat_messages_by_thread_id_not_deleted
    SQL
  end
end
