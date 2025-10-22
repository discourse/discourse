# frozen_string_literal: true
class AddIndexToPostActions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_actions_on_agreed_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_post_actions_on_agreed_by_id ON post_actions(agreed_by_id) WHERE agreed_by_id IS NOT NULL
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_actions_on_deferred_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_post_actions_on_deferred_by_id ON post_actions(deferred_by_id) WHERE deferred_by_id IS NOT NULL
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_actions_on_deleted_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_post_actions_on_deleted_by_id ON post_actions(deleted_by_id) WHERE deleted_by_id IS NOT NULL
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_post_actions_on_disagreed_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_post_actions_on_disagreed_by_id ON post_actions(disagreed_by_id) WHERE disagreed_by_id IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_post_actions_on_agreed_by_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_post_actions_on_deferred_by_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_post_actions_on_deleted_by_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_post_actions_on_disagreed_by_id
    SQL
  end
end
