# frozen_string_literal: true
class AddIndexToPosts < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_posts_on_deleted_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_posts_on_deleted_by_id ON posts(deleted_by_id) WHERE deleted_by_id IS NOT NULL
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_posts_on_last_editor_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_posts_on_last_editor_id ON posts(last_editor_id) WHERE last_editor_id IS NOT NULL
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_posts_on_locked_by_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_posts_on_locked_by_id ON posts(locked_by_id) WHERE locked_by_id IS NOT NULL
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_posts_on_reply_to_user_id
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_posts_on_reply_to_user_id ON posts(reply_to_user_id) WHERE reply_to_user_id IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_posts_on_deleted_by_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_posts_on_last_editor_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_posts_on_locked_by_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_posts_on_reply_to_user_id
    SQL
  end
end
