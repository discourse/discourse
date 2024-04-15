# frozen_string_literal: true

class UpdateChatChannelMessageCounts < ActiveRecord::Migration[7.0]
  def up
    DB.exec <<~SQL
      UPDATE chat_channels channels
      SET messages_count = subquery.messages_count
      FROM (
        SELECT COUNT(*) AS messages_count, chat_channel_id
        FROM chat_messages
        WHERE chat_messages.deleted_at IS NULL
        GROUP BY chat_channel_id
      ) subquery
      WHERE channels.id = subquery.chat_channel_id
      AND channels.deleted_at IS NULL
      AND subquery.messages_count != channels.messages_count
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
