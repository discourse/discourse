# frozen_string_literal: true

class FixPostsAndTopicsWithInvalidUserId < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  BATCH_SIZE = 5000

  def up
    # Posts
    begin
      updated_count =
        DB.exec(<<~SQL, batch_size: BATCH_SIZE, system_user_id: Discourse::SYSTEM_USER_ID)
          UPDATE posts
          SET user_id = :system_user_id
          WHERE id IN (
            SELECT posts.id
            FROM posts
            LEFT JOIN users ON posts.user_id = users.id
            WHERE posts.user_id IS NULL OR users.id IS NULL
            LIMIT :batch_size
          )
        SQL
    end while updated_count > 0

    # Topics
    begin
      updated_count =
        DB.exec(<<~SQL, batch_size: BATCH_SIZE, system_user_id: Discourse::SYSTEM_USER_ID)
          WITH batch AS (
            SELECT topics.id AS topic_id, posts.user_id AS first_post_user_id
            FROM topics
            LEFT JOIN users ON topics.user_id = users.id
            LEFT JOIN posts ON topics.id = posts.topic_id AND posts.post_number = 1
            WHERE topics.user_id IS NULL OR users.id IS NULL
            LIMIT :batch_size
          )
          UPDATE topics
          SET user_id = COALESCE(batch.first_post_user_id, :system_user_id)
          FROM batch
          WHERE id = batch.topic_id
      SQL
    end while updated_count > 0
  end

  def down
  end
end
