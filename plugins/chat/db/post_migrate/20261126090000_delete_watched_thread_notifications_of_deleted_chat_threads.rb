# frozen_string_literal: true

class DeleteWatchedThreadNotificationsOfDeletedChatThreads < ActiveRecord::Migration[8.1]
  CHAT_WATCHED_THREAD_NOTIFICATION_TYPE = 40

  def up
    execute <<~SQL
      DELETE FROM notifications
      USING user_chat_thread_memberships
      WHERE notifications.user_id = user_chat_thread_memberships.user_id
        AND notifications.notification_type = #{CHAT_WATCHED_THREAD_NOTIFICATION_TYPE}
        AND notifications.data::json ->> 'chat_thread_id' = user_chat_thread_memberships.thread_id::text
        AND NOT EXISTS (
          SELECT 1
          FROM chat_threads
          JOIN chat_messages ON chat_messages.id = chat_threads.original_message_id
          WHERE chat_threads.id = user_chat_thread_memberships.thread_id
            AND chat_messages.deleted_at IS NULL
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
