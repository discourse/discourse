# frozen_string_literal: true
class TrashFirstPostOfTrashedTopicsInDeletedCategories < ActiveRecord::Migration[8.1]
  SMALL_ACTION_POST_TYPE = 3
  WHISPER_POST_TYPE = 4

  def up
    execute <<~SQL
      WITH trashed_first_posts AS (
        UPDATE posts
        SET deleted_at = topics.deleted_at, deleted_by_id = topics.deleted_by_id
        FROM topics
        WHERE posts.topic_id = topics.id
          AND posts.post_number = 1
          AND posts.deleted_at IS NULL
          AND topics.deleted_at IS NOT NULL
          AND topics.category_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM categories WHERE categories.id = topics.category_id)
        RETURNING posts.topic_id
      )
      UPDATE topics
      SET posts_count = (
        SELECT COUNT(*)
        FROM posts
        WHERE posts.topic_id = topics.id
          AND posts.post_number > 1
          AND posts.deleted_at IS NULL
          AND posts.post_type NOT IN (#{SMALL_ACTION_POST_TYPE}, #{WHISPER_POST_TYPE})
      )
      FROM trashed_first_posts
      WHERE topics.id = trashed_first_posts.topic_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
