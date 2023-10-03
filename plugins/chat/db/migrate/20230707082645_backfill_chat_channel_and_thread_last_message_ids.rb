# frozen_string_literal: true

class BackfillChatChannelAndThreadLastMessageIds < ActiveRecord::Migration[7.0]
  def up
    execute <<-SQL
      UPDATE chat_channels
      SET last_message_id = (
        SELECT cm.id
        FROM chat_messages cm
        LEFT JOIN chat_threads ON chat_threads.original_message_id = cm.id
        WHERE cm.chat_channel_id = chat_channels.id
          AND cm.deleted_at IS NULL
          AND (cm.thread_id IS NULL OR chat_threads.id IS NOT NULL)
        ORDER BY cm.created_at DESC, cm.id DESC
        LIMIT 1
      );
    SQL

    execute <<-SQL
      UPDATE chat_threads
      SET last_message_id = (
        SELECT cm.id
        FROM chat_messages cm
        WHERE cm.thread_id = chat_threads.id
          AND cm.deleted_at IS NULL
        ORDER BY cm.created_at DESC, cm.id DESC
        LIMIT 1
      );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
