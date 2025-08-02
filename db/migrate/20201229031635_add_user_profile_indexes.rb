# frozen_string_literal: true

class AddUserProfileIndexes < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_topic_links_on_user_and_clicks
      ON topic_links(user_id, clicks DESC, created_at DESC)
      WHERE (NOT reflection and NOT quote and NOT internal)
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_posts_user_and_likes
      ON posts(user_id, like_count desc, created_at desc)
      WHERE post_number > 1
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_posts_user_and_likes
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_topic_links_on_user_and_clicks
    SQL
  end
end
