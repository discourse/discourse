# frozen_string_literal: true

class CopyNotificationsIdIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Short-circuit if the table has been migrated already
    result =
      execute(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'id' LIMIT 1",
      )
    data_type = result[0]["data_type"]
    return if data_type.downcase == "bigint"

    # Copy existing indexes and suffix them with `_bigint`
    results =
      execute(
        "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications' AND indexdef SIMILAR TO '%\\mid\\M%' AND schemaname = 'public'",
      )
    results.each do |res|
      indexname, indexdef = res["indexname"], res["indexdef"]

      indexdef = indexdef.gsub(/\b#{indexname}\b/, "#{indexname}_bigint")
      indexdef =
        indexdef.gsub(
          /\bCREATE (UNIQUE )?INDEX\b/,
          "CREATE \\1INDEX CONCURRENTLY",
        ) if !Rails.env.test?
      indexdef = indexdef.gsub(/\bid\b/, "new_id")

      execute "DROP INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} IF EXISTS #{indexname}_bigint"
      execute(indexdef)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
