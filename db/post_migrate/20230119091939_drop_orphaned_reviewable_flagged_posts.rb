# frozen_string_literal: true

class DropOrphanedReviewableFlaggedPosts < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      DELETE FROM reviewables
      WHERE reviewables.type = 'ReviewableFlaggedPost'
        AND reviewables.status = 0
        AND reviewables.target_type = 'Post'
        AND NOT EXISTS(SELECT 1 FROM posts WHERE posts.id = reviewables.target_id)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
