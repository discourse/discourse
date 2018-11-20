class MoveAutoCloseColumnsToTopicStatusUpdate < ActiveRecord::Migration[4.2]
  def up
    # The 1 in the fourth column is TopicStatusUpdate.types[:close], an enum with value 1.
    execute <<~SQL
    INSERT INTO topic_status_updates(topic_id, user_id, execute_at, status_type, based_on_last_post, created_at, updated_at)
    SELECT
      t.id,
      t.auto_close_user_id,
      t.auto_close_at,
      1,
      t.auto_close_based_on_last_post,
      t.auto_close_started_at,
      t.auto_close_started_at
    FROM topics t
    WHERE t.auto_close_at IS NOT NULL
    AND t.auto_close_user_id IS NOT NULL
    AND t.auto_close_started_at IS NOT NULL
    AND t.deleted_at IS NULL
    SQL

    execute <<~SQL
    WITH selected AS (
      SELECT tsp.id
      FROM topic_status_updates tsp
      JOIN topics t
      ON t.id = tsp.topic_id
      WHERE tsp.execute_at < now()
      OR (t.closed AND tsp.execute_at >= now())
    )

    UPDATE topic_status_updates
    SET deleted_at = now(), deleted_by_id = #{Discourse::SYSTEM_USER_ID}
    WHERE id in (SELECT * FROM selected)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
