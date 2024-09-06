# frozen_string_literal: true
class SwapBigintChatMentionNotificationsNotificationId < ActiveRecord::Migration[7.1]
  def up
    # Necessary to rename and drop trigger/function
    Migration::SafeMigrate.disable!

    # Drop trigger and function used to replicate new values
    execute "DROP TRIGGER chat_mention_notifications_new_notification_id_trigger ON chat_mention_notifications"
    execute "DROP FUNCTION mirror_chat_mention_notifications_notification_id()"

    # Swap columns
    execute "ALTER TABLE chat_mention_notifications RENAME COLUMN notification_id TO old_notification_id"
    execute "ALTER TABLE chat_mention_notifications RENAME COLUMN new_notification_id TO notification_id"

    # Drop old indexes
    execute "DROP INDEX index_chat_mention_notifications_on_notification_id"
    execute "ALTER INDEX index_chat_mention_notifications_on_new_notification_id RENAME TO index_chat_mention_notifications_on_notification_id"

    execute "ALTER TABLE chat_mention_notifications ALTER COLUMN old_notification_id DROP NOT NULL"
    execute "ALTER TABLE chat_mention_notifications ALTER COLUMN notification_id DROP DEFAULT"

    # Keep old column and mark it as read only
    Migration::ColumnDropper.mark_readonly(:chat_mention_notifications, :old_notification_id)
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
