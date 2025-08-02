# frozen_string_literal: true

class SwapBigIntUserBadgesNotificationId < ActiveRecord::Migration[7.0]
  def up
    # Necessary to rename and drop columns
    Migration::SafeMigrate.disable!

    # Drop trigger and function used to replicate new values
    execute "DROP TRIGGER user_badges_new_notification_id_trigger ON user_badges"
    execute "DROP FUNCTION mirror_user_badges_notification_id()"

    # Swap columns
    execute "ALTER TABLE user_badges RENAME COLUMN notification_id TO old_notification_id"
    execute "ALTER TABLE user_badges RENAME COLUMN new_notification_id TO notification_id"

    # Keep old column and mark it as read only
    Migration::ColumnDropper.mark_readonly(:user_badges, :old_notification_id)
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
