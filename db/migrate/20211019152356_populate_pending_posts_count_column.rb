# frozen_string_literal: true

class PopulatePendingPostsCountColumn < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      WITH to_update AS (
        SELECT COUNT(id) AS posts, created_by_id
        FROM reviewables
        WHERE type = 'ReviewableQueuedPost'
          AND status = #{ReviewableQueuedPost.statuses[:pending]}
        GROUP BY created_by_id
      )
      UPDATE user_stats
      SET pending_posts_count = to_update.posts
      FROM to_update
      WHERE to_update.created_by_id = user_stats.user_id
    SQL
  end

  def down
  end
end
