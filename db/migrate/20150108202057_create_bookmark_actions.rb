class CreateBookmarkActions < ActiveRecord::Migration
  def up
    execute "INSERT INTO user_actions (action_type,
                                       user_id,
                                       target_topic_id,
                                       target_post_id,
                                       acting_user_id,
                                       created_at,
                                       updated_at)
             SELECT DISTINCT 3,
                    pa.user_id,
                    p.topic_id,
                    pa.post_id,
                    pa.user_id,
                    pa.created_at,
                    pa.updated_at
             FROM post_actions AS pa
             INNER JOIN posts AS p ON p.id = pa.post_id AND p.post_number = 1
             WHERE NOT EXISTS (SELECT 1 FROM user_actions AS ua WHERE ua.target_post_id = pa.post_id AND ua.action_type = 3 AND ua.user_id = pa.user_id)
             AND pa.post_action_type_id = 1
             AND pa.deleted_at IS NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
