# frozen_string_literal: true

class AddIndexTopicsOnTimestampsPrivate < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    CREATE INDEX CONCURRENTLY IF NOT EXISTS
    index_topics_on_timestamps_private
    ON topics (bumped_at, created_at, updated_at)
    WHERE deleted_at IS NULL AND archetype = 'private_message'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
