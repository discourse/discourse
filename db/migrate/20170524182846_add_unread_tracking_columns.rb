class AddUnreadTrackingColumns < ActiveRecord::Migration
  def up
    add_column :user_stats, :first_topic_unread_at, :datetime, null: false, default: "epoch"
    add_column :topics, :last_unread_at, :datetime, null: false, default: "epoch"

    execute <<SQL
    UPDATE topics SET last_unread_at = (
      SELECT MAX(created_at)
      FROM posts
      WHERE topics.id = posts.topic_id
    )
SQL

    execute <<SQL
    UPDATE user_stats SET first_topic_unread_at = COALESCE((
      SELECT MIN(last_unread_at) FROM topics
      JOIN users u ON u.id = user_stats.user_id
      JOIN topic_users tu ON tu.user_id = user_stats.user_id AND topics.id = tu.topic_id
      WHERE notification_level > 1 AND last_read_post_number < CASE WHEN moderator OR admin
                                                                THEN topics.highest_staff_post_number
                                                                ELSE topics.highest_post_number
                                                               END
        AND topics.deleted_at IS NULL
    ), current_timestamp)
SQL

    add_index :topics, [:last_unread_at]

    # we need this function for performance reasons
    execute <<SQL
    CREATE OR REPLACE FUNCTION first_unread_topic_for(user_id int)
    RETURNS timestamp AS
    $$
    SELECT COALESCE(first_topic_unread_at, 'epoch'::timestamp)
    FROM users u
    JOIN user_stats ON user_id = u.id
    WHERE u.id = $1
    $$
    LANGUAGE SQL STABLE
SQL
  end

  def down
    execute "DROP FUNCTION first_unread_topic_for(int)"
    remove_column :user_stats, :first_topic_unread_at
    remove_column :topics, :last_unread_at
  end
end
