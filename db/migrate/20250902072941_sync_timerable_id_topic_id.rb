# frozen_string_literal: true

class SyncTimerableIdTopicId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    min_id, max_id = execute("SELECT MIN(id), MAX(id) FROM topic_timers")[0].values
    batch_size = 10_000

    (min_id..max_id).step(batch_size) { |start_id| execute <<~SQL.squish } if min_id && max_id
        UPDATE topic_timers
        SET timerable_id = topic_id
        WHERE id >= #{start_id} AND id < #{start_id + batch_size} AND (timerable_id IS NULL OR timerable_id <> topic_id)
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
