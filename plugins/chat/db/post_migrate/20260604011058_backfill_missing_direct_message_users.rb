# frozen_string_literal: true

class BackfillMissingDirectMessageUsers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      INSERT INTO direct_message_users (user_id, direct_message_channel_id, created_at, updated_at)
      SELECT DISTINCT
        user_chat_channel_memberships.user_id,
        chat_channels.chatable_id,
        user_chat_channel_memberships.created_at,
        user_chat_channel_memberships.updated_at
      FROM user_chat_channel_memberships
      INNER JOIN chat_channels
        ON chat_channels.id = user_chat_channel_memberships.chat_channel_id
       AND chat_channels.chatable_type = 'DirectMessage'
      LEFT JOIN direct_message_users
        ON direct_message_users.user_id = user_chat_channel_memberships.user_id
       AND direct_message_users.direct_message_channel_id = chat_channels.chatable_id
      WHERE direct_message_users.id IS NULL
      ON CONFLICT (direct_message_channel_id, user_id) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
