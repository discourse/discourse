# frozen_string_literal: true

class UpdateChatChannelMessageCounts < ActiveRecord::Migration[7.0]
  def up
    DB.exec <<~SQL
      UPDATE chat_channels channels
      SET chat_message_count = subquery.chat_message_count
      FROM (
        SELECT COUNT(*) AS chat_message_count, chat_channel_id
        FROM chat_messages
        WHERE chat_messages.deleted_at IS NULL
        GROUP BY chat_channel_id
      ) subquery
      WHERE channels.id = subquery.chat_channel_id
      AND channels.deleted_at IS NULL
      AND subquery.chat_message_count != channels.chat_message_count
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
