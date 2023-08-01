# frozen_string_literal: true

class RemoveCorruptedLastReadMessageId < ActiveRecord::Migration[7.0]
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def up
    # Delete memberships for deleted channels
    execute <<~SQL
      DELETE FROM user_chat_channel_memberships uccm
      WHERE NOT EXISTS (
        SELECT FROM chat_channels cc
        WHERE cc.id = uccm.chat_channel_id
      );
    SQL

    # Delete messages for deleted channels
    execute <<~SQL
      DELETE FROM chat_messages cm
      WHERE NOT EXISTS (
        SELECT FROM chat_channels cc
        WHERE cc.id = cm.chat_channel_id
      );
    SQL

    # Reset highest_channel_message_id if the message cannot be found in the channel
    execute <<~SQL
      WITH highest_channel_message_id AS (
        SELECT chat_channel_id, max(chat_messages.id) as highest_id
        FROM chat_messages
        GROUP BY chat_channel_id
      )
      UPDATE user_chat_channel_memberships uccm
      SET last_read_message_id = highest_channel_message_id.highest_id
      FROM highest_channel_message_id
      WHERE highest_channel_message_id.chat_channel_id = uccm.chat_channel_id
      AND uccm.last_read_message_id IS NOT NULL
      AND uccm.last_read_message_id NOT IN (
        SELECT id FROM chat_messages WHERE chat_messages.chat_channel_id = uccm.chat_channel_id
      )
    SQL

    # Nullify in_reply_to where message is deleted
    execute <<~SQL
      UPDATE chat_messages cm
      SET in_reply_to_id = NULL
      WHERE NOT EXISTS (
        SELECT FROM chat_messages cm2
        WHERE cm.in_reply_to_id = cm2.id
      );
    SQL

    # Delete chat_message_revisions with no message linked
    execute <<~SQL
      DELETE FROM chat_message_revisions cmr
      WHERE NOT EXISTS (
        SELECT FROM chat_messages cm
        WHERE cm.id = cmr.chat_message_id
      );
    SQL

    # Delete chat_message_reactions with no message linked
    execute <<~SQL
      DELETE FROM chat_message_reactions cmr
      WHERE NOT EXISTS (
        SELECT FROM chat_messages cm
        WHERE cm.id = cmr.chat_message_id
      );
    SQL

    # Delete bookmarks with no message linked
    execute <<~SQL
      DELETE FROM bookmarks b
      WHERE b.bookmarkable_type = 'ChatMessage'
      AND NOT EXISTS (
        SELECT FROM chat_messages cm
        WHERE cm.id = b.bookmarkable_id
      );
    SQL

    # Delete chat_mention with no message linked
    execute <<~SQL
      DELETE FROM chat_mentions
      WHERE NOT EXISTS (
        SELECT FROM chat_messages cm
        WHERE cm.id = chat_mentions.chat_message_id
      );
    SQL

    # Delete chat_webhook_event with no message linked
    execute <<~SQL
      DELETE FROM chat_webhook_events cwe
      WHERE NOT EXISTS (
        SELECT FROM chat_messages cm
        WHERE cm.id = cwe.chat_message_id
      );
    SQL

    # Delete chat_uploads with no message linked
    execute <<~SQL
      DELETE FROM chat_uploads
      WHERE NOT EXISTS (
        SELECT FROM chat_messages cm
        WHERE cm.id = chat_uploads.chat_message_id
      );
    SQL
  end
end
