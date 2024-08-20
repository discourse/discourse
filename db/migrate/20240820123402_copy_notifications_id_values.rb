# frozen_string_literal: true

class CopyNotificationsIdValues < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Short-circuit if the table has been migrated already
    result =
      execute(
        "SELECT data_type FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'id' LIMIT 1",
      )
    data_type = result[0]["data_type"]
    return if data_type.downcase == "bigint"

    min_id, max_id = execute("SELECT MIN(id), MAX(id) FROM notifications")[0].values
    batch_size = 10_000

    (min_id..max_id).step(batch_size) { |start_id| execute <<~SQL } if min_id && max_id
        UPDATE notifications
        SET new_id = id
        WHERE id >= #{start_id} AND id < #{start_id + batch_size} AND new_id != id
      SQL

    # Copy existing indexes and suffix them with `_bigint`
    results =
      execute(
        "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'notifications' AND indexdef SIMILAR TO '%\\mid\\M%'",
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

      execute "DROP INDEX IF EXISTS #{indexname}_bigint"
      execute(indexdef)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
