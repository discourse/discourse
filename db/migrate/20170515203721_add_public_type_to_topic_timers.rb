class AddPublicTypeToTopicTimers < ActiveRecord::Migration
  def up
    add_column :topic_timers, :public_type, :boolean, default: true

    execute("drop index idx_topic_id_status_type_deleted_at") rescue nil

    # Only one public timer per topic (close, open, delete):
    execute <<~SQL
    CREATE UNIQUE INDEX idx_topic_id_public_type_deleted_at
    ON topic_timers (topic_id)
    WHERE public_type = TRUE
    AND deleted_at IS NULL
    SQL
  end

  def down
    execute "DROP INDEX idx_topic_id_public_type_deleted_at"

    execute <<~SQL
    CREATE UNIQUE INDEX idx_topic_id_status_type_deleted_at
    ON topic_timers (topic_id, status_type)
    WHERE deleted_at IS NULL
    SQL

    remove_column :topic_timers, :public_type
  end
end
