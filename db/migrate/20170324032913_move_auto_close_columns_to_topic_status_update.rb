class MoveAutoCloseColumnsToTopicStatusUpdate < ActiveRecord::Migration
  def up
    execute <<~SQL
    INSERT INTO topic_status_updates(topic_id, user_id, execute_at, status_type, based_on_last_post, created_at, updated_at)
    SELECT
      t.id,
      t.auto_close_user_id,
      t.auto_close_at,
      #{TopicStatusUpdate.types[:close]},
      t.auto_close_based_on_last_post,
      t.auto_close_started_at,
      t.auto_close_started_at
    FROM topics t
    WHERE t.auto_close_at IS NOT NULL
    AND t.auto_close_user_id IS NOT NULL
    AND t.auto_close_started_at IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
