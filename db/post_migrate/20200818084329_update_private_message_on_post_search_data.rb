# frozen_string_literal: true

class UpdatePrivateMessageOnPostSearchData < ActiveRecord::Migration[6.0]
  # this is a very big change ... avoid an enormous transaction here
  disable_ddl_transaction!

  def update_private_message_flag

    sql = <<~SQL
      UPDATE post_search_data
      SET private_message = X.private_message
      FROM
      (
        SELECT post_id,
          CASE WHEN t.archetype = 'private_message' THEN TRUE ELSE FALSE END private_message
        FROM posts p
        JOIN post_search_data pd ON pd.post_id = p.id
        JOIN topics t ON t.id = p.topic_id
        WHERE pd.private_message IS NULL OR
          pd.private_message <> CASE WHEN t.archetype = 'private_message' THEN TRUE ELSE FALSE END
        LIMIT 3000000
      ) X
      WHERE X.post_id = post_search_data.post_id
    SQL

    while true
      count = execute(sql).cmd_tuples
      if count == 0
        break
      else
        puts "Migrated batch of #{count} on post_search_date to new schema"
      end
    end
  end

  def up

    # must drop index cause we do not want an enormous amount of work done
    # as we are changing data
    execute <<~SQL
     DROP INDEX IF EXISTS idx_regular_post_search_data
    SQL

    # Delete post_search_data of orphaned posts
    execute <<~SQL
    DELETE FROM post_search_data
    WHERE post_id IN (
      SELECT posts.id
      FROM posts
      LEFT JOIN topics ON topics.id = posts.topic_id
      WHERE topics.id IS NULL
    )
    SQL

    # Delete orphaned post_search_data
    execute <<~SQL
    DELETE FROM post_search_data
    WHERE post_id IN (
      SELECT post_search_data.post_id
      FROM post_search_data
      LEFT JOIN posts ON posts.id = post_search_data.post_id
      WHERE posts.id IS NULL
    )
    SQL

    update_private_message_flag

    ActiveRecord::Base.transaction do
      update_private_message_flag
      change_column_null(:post_search_data, :private_message, false)
    end

    execute <<~SQL
      CREATE INDEX CONCURRENTLY idx_regular_post_search_data
       ON post_search_data USING GIN(search_data) WHERE NOT private_message
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
