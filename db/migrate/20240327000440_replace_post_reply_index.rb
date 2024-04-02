# frozen_string_literal: true

class ReplacePostReplyIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS "index_posts_on_topic_id_and_reply_to_post_number"
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS "index_posts_on_topic_id_and_reply_to_post_number"
      ON "posts" ("topic_id", "reply_to_post_number")
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS "index_posts_on_reply_to_post_number"
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS "index_posts_on_reply_to_post_number"
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS "index_posts_on_reply_to_post_number"
      ON "posts" ("reply_to_post_number")
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS "index_posts_on_topic_id_and_reply_to_post_number"
    SQL
  end
end
