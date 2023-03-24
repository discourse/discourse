# frozen_string_literal: true

class AddIndexToPostsWhereNotDeletedOrEmpty < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_posts_on_id_topic_id_where_not_deleted_or_empty
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY index_posts_on_id_topic_id_where_not_deleted_or_empty ON posts (id, topic_id) where deleted_at IS NULL AND raw <> ''
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_posts_on_id_topic_id_where_not_deleted_or_empty
    SQL
  end
end
