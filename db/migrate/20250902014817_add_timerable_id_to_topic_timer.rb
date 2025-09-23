# frozen_string_literal: true
class AddTimerableIdToTopicTimer < ActiveRecord::Migration[8.0]
  def up
    add_column :topic_timers, :timerable_id, :integer
    add_index :topic_timers,
              :timerable_id,
              unique: true,
              name: :idx_timerable_id_public_type_deleted_at,
              where: "public_type = true AND deleted_at IS NULL AND type = 'TopicTimer'"
    add_index :topic_timers, :timerable_id, where: "deleted_at IS NULL"
    change_column_null :topic_timers, :topic_id, true
    Migration::ColumnDropper.mark_readonly(:topic_timers, :topic_id)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
