# frozen_string_literal: true

class AddIndexToChatMessagesOnChatChannelId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # Transaction has been disabled so we need to clean up the invalid index if index creation timeout
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS index_chat_messages_on_chat_channel_id_and_id
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY index_chat_messages_on_chat_channel_id_and_id
    ON chat_messages (chat_channel_id,id)
    WHERE deleted_at IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
