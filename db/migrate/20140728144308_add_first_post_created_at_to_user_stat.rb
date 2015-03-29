class AddFirstPostCreatedAtToUserStat < ActiveRecord::Migration
  def up
    add_column :user_stats, :first_post_created_at, :datetime

    execute <<-SQL
      WITH first_posts AS (
        SELECT p.id,
               p.user_id,
               p.created_at,
               ROW_NUMBER() OVER (PARTITION BY p.user_id ORDER BY p.created_at ASC) AS row
          FROM posts p
      )
      UPDATE user_stats us
         SET first_post_created_at = fp.created_at
        FROM first_posts fp
       WHERE fp.row = 1
         AND fp.user_id = us.user_id
    SQL
  end

  def down
    remove_column :user_stats, :first_post_created_at
  end
end
