class AddUserExtras < ActiveRecord::Migration
  def up

    # NOTE: our user table is getting bloated, we probably want to split it for performance
    # put lesser used columns into a user_extras table and frequently used ones here.
    add_column :users, :likes_given, :integer, null: false, default: 0
    add_column :users, :likes_received, :integer, null: false, default: 0
    add_column :users, :topic_reply_count, :integer, null: false, default: 0


    # NOTE: to keep migrations working through refactorings we avoid externalizing this stuff.
    #   even though a helper method may make sense
    execute <<SQL
UPDATE users u
SET
    likes_given = X.likes_given
FROM (
  SELECT
    a.user_id,
    COUNT(*) likes_given
  FROM user_actions a
  JOIN posts p ON p.id = a.target_post_id
  WHERE p.deleted_at IS NULL AND a.action_type = 1
  GROUP BY a.user_id
) as X
WHERE X.user_id = u.id
SQL

  execute <<SQL
UPDATE users u
SET
    likes_received = Y.likes_received
FROM (
  SELECT
    a.user_id,
    COUNT(*) likes_received
  FROM user_actions a
  JOIN posts p ON p.id = a.target_post_id
  WHERE p.deleted_at IS NULL AND a.action_type = 2
  GROUP BY a.user_id
) as Y
WHERE Y.user_id = u.id
SQL

  execute <<SQL
UPDATE users u
SET
    topic_reply_count = Z.topic_reply_count
FROM (
  SELECT
    p.user_id,
    COUNT(DISTINCT topic_id) topic_reply_count
  FROM posts p
  JOIN topics t on t.id = p.topic_id
  WHERE t.user_id <> p.user_id AND
        p.deleted_at IS NULL AND t.deleted_at IS NULL
  GROUP BY p.user_id
) Z
WHERE
  Z.user_id = u.id
SQL

  end

  def down
    remove_column :users, :likes_given
    remove_column :users, :likes_received
    remove_column :users, :topic_reply_count
  end
end
