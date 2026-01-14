# frozen_string_literal: true
class AddIndexCreatedAtOnWebHookEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_web_hook_events_on_created_at
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_web_hook_events_on_created_at
      ON web_hook_events USING btree (created_at)
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_web_hook_events_on_created_at
    SQL
  end
end
