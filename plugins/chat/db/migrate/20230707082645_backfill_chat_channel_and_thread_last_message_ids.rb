# frozen_string_literal: true

class BackfillChatChannelAndThreadLastMessageIds < ActiveRecord::Migration[7.0]
  def up
    # TODO (martin) Write a spec for this migration
    execute <<-SQL
      UPDATE chat_channels
      SET last_message_id = subquery.last_message_id
      FROM (
        SELECT chat_channels.id AS channel_id, MAX(chat_messages.id) AS last_message_id
        FROM chat_channels
        INNER JOIN chat_messages ON chat_messages.chat_channel_id = chat_channels.id
        LEFT JOIN chat_threads ON chat_threads.original_message_id = chat_messages.id
        WHERE chat_messages.deleted_at IS NULL
       -- this is so only the original message of a thread is counted not all thread messages
        AND chat_messages.thread_id IS NULL OR chat_threads.id IS NOT NULL
        GROUP BY chat_channels.id
      ) subquery
      WHERE chat_channels.id = subquery.channel_id
    SQL

    execute <<-SQL
      UPDATE chat_threads
      SET last_message_id = subquery.last_message_id
      FROM (
        SELECT chat_threads.id AS thread_id, MAX(chat_messages.id) AS last_message_id
        FROM chat_threads
        INNER JOIN chat_messages ON chat_messages.thread_id = chat_threads.id
        WHERE chat_messages.deleted_at IS NULL
        GROUP BY chat_threads.id
      ) subquery
      WHERE chat_threads.id = subquery.thread_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
