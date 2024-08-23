# frozen_string_literal: true

class SwapBigIntNotificationsId < ActiveRecord::Migration[7.0]
  def up
    # Short-circuit if the table has been migrated already
    result =
      execute(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'id' LIMIT 1",
      )
    data_type = result[0]["data_type"]
    return if data_type.downcase == "bigint"

    # Necessary to rename and drop columns
    Migration::SafeMigrate.disable!

    # Drop trigger and function used to replicate new values
    execute "DROP TRIGGER notifications_new_id_trigger ON notifications"
    execute "DROP FUNCTION mirror_notifications_id()"

    # Move sequence to new column
    execute "ALTER TABLE notifications ALTER COLUMN id DROP DEFAULT"
    execute "ALTER TABLE notifications ALTER COLUMN new_id SET DEFAULT nextval('notifications_id_seq'::regclass)"
    execute "ALTER SEQUENCE notifications_id_seq OWNED BY notifications.new_id"

    # Swap columns
    execute "ALTER TABLE notifications RENAME COLUMN id TO old_id"
    execute "ALTER TABLE notifications RENAME COLUMN new_id TO id"

    # Recreate primary key
    execute "ALTER TABLE notifications DROP CONSTRAINT notifications_pkey"
    execute "ALTER TABLE notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY USING INDEX notifications_pkey_bigint"

    # Keep old column and mark it as read only
    execute "ALTER TABLE notifications ALTER COLUMN old_id DROP NOT NULL"
    Migration::ColumnDropper.mark_readonly(:notifications, :old_id)
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
