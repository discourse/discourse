# frozen_string_literal: true

class UpdatePrivateMessageOnPostSearchData < ActiveRecord::Migration[6.0]
  # this is a very big change ... avoid an enormous transaction here
  disable_ddl_transaction!

  def update_private_message_flag
    execute <<~SQL
    UPDATE post_search_data
    SET private_message = true
    FROM posts
    INNER JOIN topics ON topics.id = posts.topic_id AND topics.archetype = 'private_message'
    WHERE posts.id = post_search_data.post_id AND
      (private_message IS NULL or private_message = false)
    SQL

    execute <<~SQL
    UPDATE post_search_data
    SET private_message = false
    FROM posts
    INNER JOIN topics ON topics.id = posts.topic_id AND topics.archetype <> 'private_message'
    WHERE posts.id = post_search_data.post_id AND
      (private_message IS NULL or private_message = true)
    SQL
  end

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

    update_private_message_flag

    ActiveRecord::Base.transaction do
      update_private_message_flag
      change_column_null(:post_search_data, :private_message, false)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
