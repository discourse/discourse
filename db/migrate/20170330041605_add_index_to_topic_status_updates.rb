class AddIndexToTopicStatusUpdates < ActiveRecord::Migration
  def up
    execute <<~SQL
    CREATE UNIQUE INDEX idx_topic_id_status_type_deleted_at
    ON topic_status_updates(topic_id, status_type)
    WHERE deleted_at IS NULL
    SQL
  end

  def down
    execute "DROP INDEX idx_topic_id_status_type_deleted_at"
  end
end
