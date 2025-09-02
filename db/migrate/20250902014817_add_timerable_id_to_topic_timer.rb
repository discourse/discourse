# frozen_string_literal: true
class AddTimerableIdToTopicTimer < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_timers, :timerable_id, :integer, null: false
    execute <<-SQL
      UPDATE topic_timers SET timerable_id = topic_id;
    SQL
    add_index :topic_timers,
              :timerable_id,
              unique: true,
              name: :idx_timerable_id_public_type_deleted_at,
              where: "public_type = true AND deleted_at IS NULL AND type = 'TopicTimer'"
    add_index :topic_timers, :timerable_id, where: "deleted_at IS NULL"
    change_column_null :timers, :topic_id, true
  end
end
