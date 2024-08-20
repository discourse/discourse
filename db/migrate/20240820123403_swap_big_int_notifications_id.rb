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

    execute "DROP TRIGGER notifications_new_id_trigger ON notifications"
    execute "DROP FUNCTION mirror_notifications_id()"

    execute "ALTER TABLE notifications RENAME COLUMN id TO old_id"
    execute "ALTER TABLE notifications RENAME COLUMN new_id TO id"

    execute "ALTER TABLE notifications ALTER COLUMN old_id DROP DEFAULT"
    execute "ALTER TABLE notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass)"

    execute "ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id"

    execute "ALTER TABLE notifications DROP CONSTRAINT notifications_pkey"
    execute "ALTER TABLE notifications ADD CONSTRAINT notifications_pkey PRIMARY KEY USING INDEX notifications_pkey_bigint"

    execute "ALTER TABLE notifications DROP COLUMN old_id"

    # Remove `_bigint` suffix from indexes
    results =
      execute(
        "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications' AND indexdef SIMILAR TO '%\\mid\\M%'",
      )
    results.each do |res|
      indexname, indexdef = res["indexname"], res["indexdef"]
      if indexname.include?("_bigint")
        execute "ALTER INDEX #{indexname} RENAME TO #{indexname.gsub(/_bigint$/, "")}"
      end
    end
  ensure
    Migration::SafeMigrate.enable!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
