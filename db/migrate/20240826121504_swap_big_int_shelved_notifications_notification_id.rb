# frozen_string_literal: true

class SwapBigIntShelvedNotificationsNotificationId < ActiveRecord::Migration[7.0]
  def up
    # Necessary to rename columns and drop triggers/functions
    Migration::SafeMigrate.disable!

    # Drop trigger and function used to replicate new values
    execute "DROP TRIGGER user_badges_new_notification_id_trigger ON shelved_notifications"
    execute "DROP FUNCTION mirror_user_badges_notification_id()"

    execute "ALTER TABLE shelved_notifications ALTER COLUMN new_notification_id DROP DEFAULT"

    # Swap columns
    execute "ALTER TABLE shelved_notifications RENAME COLUMN notification_id TO old_notification_id"
    execute "ALTER TABLE shelved_notifications RENAME COLUMN new_notification_id TO notification_id"

    # Keep old column and mark it as read only
    execute "ALTER TABLE shelved_notifications ALTER COLUMN old_notification_id DROP NOT NULL"
    Migration::ColumnDropper.mark_readonly(:shelved_notifications, :old_notification_id)

    # Rename indexes
    execute "DROP INDEX IF EXISTS index_shelved_notifications_on_notification_id"
    execute "ALTER INDEX index_shelved_notifications_on_new_notification_id RENAME TO index_shelved_notifications_on_notification_id"
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
