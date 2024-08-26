# frozen_string_literal: true

class DropOldNotificationIdIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Drop old indexes
    results =
      execute(
        "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications' AND indexdef SIMILAR TO '%\\mold_id\\M%'",
      )
    results.each do |res|
      indexname, indexdef = res["indexname"], res["indexdef"]
      execute "DROP INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} IF EXISTS #{indexname}"
    end

    # Remove `_bigint` suffix from indexes
    results =
      execute(
        "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications' AND indexdef SIMILAR TO '%\\mid\\M%' AND schemaname = 'public'",
      )
    results.each do |res|
      indexname, indexdef = res["indexname"], res["indexdef"]
      if indexname.include?("_bigint")
        execute "ALTER INDEX #{indexname} RENAME TO #{indexname.gsub(/_bigint$/, "")}"
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
