# frozen_string_literal: true

class FixStaleTopicUserBookmarkedData < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    min_id, max_id =
      DB.query_single("SELECT MIN(id), MAX(id) FROM topic_users WHERE bookmarked = true")

    return if min_id.nil? || max_id.nil?

    (min_id..max_id).step(BATCH_SIZE) { |start_id| execute(<<~SQL) }
        UPDATE topic_users tu
        SET bookmarked = false
        WHERE tu.id >= #{start_id}
        AND tu.id < #{start_id + BATCH_SIZE}
        AND tu.bookmarked = true
        AND NOT EXISTS (
          SELECT 1 FROM bookmarks b
          LEFT JOIN posts p ON p.id = b.bookmarkable_id AND b.bookmarkable_type = 'Post'
          WHERE b.user_id = tu.user_id
          AND (
            (b.bookmarkable_type = 'Topic' AND b.bookmarkable_id = tu.topic_id)
            OR (b.bookmarkable_type = 'Post' AND p.topic_id = tu.topic_id AND p.deleted_at IS NULL)
          )
        )
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
