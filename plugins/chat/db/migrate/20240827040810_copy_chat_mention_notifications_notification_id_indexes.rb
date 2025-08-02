# frozen_string_literal: true
class CopyChatMentionNotificationsNotificationIdIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute "DROP INDEX #{Rails.env.test? ? "" : "CONCURRENTLY "} IF EXISTS index_chat_mention_notifications_on_new_notification_id"
    execute "CREATE UNIQUE INDEX #{Rails.env.test? ? "" : "CONCURRENTLY "} index_chat_mention_notifications_on_new_notification_id ON chat_mention_notifications (new_notification_id)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
