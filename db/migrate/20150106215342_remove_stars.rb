class RemoveStars < ActiveRecord::Migration
  def up
    r = execute <<SQL
    INSERT INTO post_actions(user_id, post_id, post_action_type_id, created_at, updated_at)
    SELECT tu.user_id, p.id, 1, coalesce(tu.starred_at, now()), coalesce(tu.starred_at, now())
    FROM topic_users tu
    JOIN posts p ON p.topic_id = tu.topic_id AND p.post_number = 1
    LEFT JOIN post_actions pa ON
        pa.post_id = p.id AND
        pa.user_id = tu.user_id AND
        pa.post_action_type_id = 1
    WHERE pa.post_id IS NULL AND tu.starred
SQL
   puts "#{r.cmd_tuples} stars were converted to bookmarks!"

   execute <<SQL
   DELETE FROM user_actions WHERE action_type = 10
SQL

    remove_column :topic_users, :starred
    remove_column :topic_users, :starred_at
    remove_column :topic_users, :unstarred_at
    remove_column :topics, :star_count
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
