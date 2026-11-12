# frozen_string_literal: true
class FixMissingChatDmChannelMemberships < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always]
  NOTIFICATION_LEVEL_ALWAYS = 2

  def up
    return if !Migration::Helpers.existing_site?
    return if !table_exists?(:user_chat_channel_memberships)
    return if !table_exists?(:direct_message_users)
    return if !table_exists?(:chat_channels)

    # Do nothing if chat is disabled.
    if DB
         .query_single(
           "SELECT COUNT(*) FROM site_settings WHERE name = 'chat_enabled' AND value = 'f'",
         )
         .first
         .to_i == 1
      return
    end

    inserted_channel_ids = DB.query_single(<<~SQL, notification_level: NOTIFICATION_LEVEL_ALWAYS)
      WITH missing AS (
        SELECT cc.id AS chat_channel_id, dmu.user_id
          FROM chat_channels cc
          JOIN direct_message_users dmu ON dmu.direct_message_channel_id = cc.chatable_id
          JOIN users u ON u.id = dmu.user_id AND u.id > 0
         WHERE cc.chatable_type = 'DirectMessage'
           AND cc.deleted_at IS NULL
           AND NOT EXISTS (
             SELECT 1
               FROM user_chat_channel_memberships m
              WHERE m.chat_channel_id = cc.id
                AND m.user_id = dmu.user_id
           )
      ), inserted AS (
        INSERT INTO user_chat_channel_memberships (
          user_id,
          chat_channel_id,
          following,
          notification_level,
          muted,
          starred,
          last_viewed_at,
          created_at,
          updated_at
        )
        SELECT
          missing.user_id,
          missing.chat_channel_id,
          TRUE,
          :notification_level,
          FALSE,
          FALSE,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
          FROM missing
        ON CONFLICT (user_id, chat_channel_id) DO NOTHING
        RETURNING chat_channel_id
      )
      SELECT DISTINCT chat_channel_id FROM inserted
    SQL

    return if inserted_channel_ids.empty?

    # Mirrors Chat::ChannelMembershipsQuery.count for DM channels (no following filter).
    DB.exec(<<~SQL, channel_ids: inserted_channel_ids)
      UPDATE chat_channels cc
         SET user_count = counts.user_count,
             user_count_stale = FALSE
        FROM (
          SELECT m.chat_channel_id, COUNT(*) AS user_count
            FROM user_chat_channel_memberships m
            JOIN users u ON u.id = m.user_id
           WHERE m.chat_channel_id IN (:channel_ids)
             AND u.id > 0
             AND u.active = TRUE
             AND u.staged = FALSE
             AND (u.suspended_till IS NULL OR u.suspended_till <= CURRENT_TIMESTAMP)
             AND (u.silenced_till IS NULL OR u.silenced_till <= CURRENT_TIMESTAMP)
           GROUP BY m.chat_channel_id
        ) counts
       WHERE cc.id = counts.chat_channel_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
