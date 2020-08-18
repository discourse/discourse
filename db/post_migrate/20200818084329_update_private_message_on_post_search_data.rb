class UpdatePrivateMessageOnPostSearchData < ActiveRecord::Migration[6.0]
  def up
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

    execute <<~SQL
    UPDATE post_search_data
    SET private_message = true
    FROM posts
    INNER JOIN topics ON topics.id = posts.topic_id AND topics.archetype = 'private_message'
    WHERE posts.id = post_search_data.post_id
    SQL

    execute <<~SQL
    UPDATE post_search_data
    SET private_message = false
    FROM posts
    INNER JOIN topics ON topics.id = posts.topic_id AND topics.archetype <> 'private_message'
    WHERE posts.id = post_search_data.post_id
    SQL

    change_column_null(:post_search_data, :private_message, false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
