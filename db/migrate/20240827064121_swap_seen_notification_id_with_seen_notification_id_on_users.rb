# frozen_string_literal: true
class SwapSeenNotificationIdWithSeenNotificationIdOnUsers < ActiveRecord::Migration[7.1]
  def up
    # Necessary to rename and drop columns
    Migration::SafeMigrate.disable!

    # Drop trigger and function used to replicate new values
    execute "DROP TRIGGER users_seen_notification_id_trigger ON users"
    execute "DROP FUNCTION mirror_users_seen_notification_id()"

    # Swap columns
    execute "ALTER TABLE users RENAME COLUMN seen_notification_id TO old_seen_notification_id"
    execute "ALTER TABLE users RENAME COLUMN new_seen_notification_id TO seen_notification_id"
    execute "ALTER TABLE users ALTER COLUMN old_seen_notification_id DROP NOT NULL"
    execute "ALTER TABLE users ALTER COLUMN old_seen_notification_id DROP DEFAULT"

    # Keep old column and mark it as read only
    Migration::ColumnDropper.mark_readonly(:users, :old_seen_notification_id)
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
