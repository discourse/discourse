# frozen_string_literal: true

class CopyShelvedNotificationsNotificationIdIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Short-circuit if the table has been migrated already
    result =
      execute(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'shelved_notifications' AND column_name = 'notification_id' LIMIT 1",
      )
    data_type = result[0]["data_type"]
    return if data_type.downcase == "bigint"

    # Copy existing indexes and suffix them with `_bigint`
    results =
      execute(
        "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'shelved_notifications' AND indexdef SIMILAR TO '%\\mnotification_id\\M%' AND schemaname = 'public'",
      )
    results.each do |res|
      indexname, indexdef = res["indexname"], res["indexdef"]

      indexdef = indexdef.gsub(/\b#{indexname}\b/, "#{indexname}_bigint")
      indexdef =
        indexdef.gsub(
          /\bCREATE (UNIQUE )?INDEX\b/,
          "CREATE \\1INDEX CONCURRENTLY",
        ) if !Rails.env.test?
      indexdef = indexdef.gsub(/\bnotification_id\b/, "new_notification_id")

      execute "DROP INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} IF EXISTS #{indexname}_bigint"
      execute(indexdef)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
