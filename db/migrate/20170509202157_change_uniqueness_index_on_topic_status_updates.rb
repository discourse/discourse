class ChangeUniquenessIndexOnTopicStatusUpdates < ActiveRecord::Migration
  def up
    execute "DROP INDEX idx_topic_id_status_type_deleted_at"

    execute <<~SQL
    CREATE UNIQUE INDEX idx_topic_id_status_type_user_id_deleted_at
    ON topic_status_updates(topic_id, status_type, user_id)
    WHERE deleted_at IS NULL
    SQL
  end

  def down
    execute "DROP INDEX idx_topic_id_status_type_user_id_deleted_at"

    execute <<~SQL
    CREATE UNIQUE INDEX idx_topic_id_status_type_deleted_at
    ON topic_status_updates(topic_id, status_type)
    WHERE deleted_at IS NULL
    SQL
  end
end
