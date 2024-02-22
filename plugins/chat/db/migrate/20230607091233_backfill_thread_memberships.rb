# frozen_string_literal: true

class BackfillThreadMemberships < ActiveRecord::Migration[7.0]
  def up
    thread_tracking_notification_level = 2

    sql = <<~SQL
      INSERT INTO user_chat_thread_memberships(
        user_id,
        thread_id,
        notification_level,
        last_read_message_id,
        created_at,
        updated_at
      )
      SELECT
        thread_participant_stats.user_id,
        thread_participant_stats.thread_id,
        #{thread_tracking_notification_level},
        (
          SELECT id FROM chat_messages
          WHERE thread_id = thread_participant_stats.thread_id
          AND deleted_at IS NULL
          ORDER BY created_at DESC, id DESC
          LIMIT 1
        ),
        NOW(),
        NOW()
      FROM (
        SELECT chat_messages.thread_id, chat_messages.user_id
        FROM chat_messages
        INNER JOIN chat_threads ON chat_threads.id = chat_messages.thread_id
        WHERE chat_messages.thread_id IS NOT NULL
        GROUP BY chat_messages.thread_id, chat_messages.user_id
        ORDER BY chat_messages.thread_id ASC, chat_messages.user_id ASC
      ) AS thread_participant_stats
      INNER JOIN users ON users.id = thread_participant_stats.user_id
      LEFT JOIN user_chat_thread_memberships ON user_chat_thread_memberships.thread_id = thread_participant_stats.thread_id
        AND user_chat_thread_memberships.user_id = thread_participant_stats.user_id
      WHERE user_chat_thread_memberships IS NULL
      ORDER BY user_chat_thread_memberships.thread_id ASC
      ON CONFLICT DO NOTHING;
    SQL

    execute(sql)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
