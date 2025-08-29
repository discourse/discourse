# frozen_string_literal: true
class AddTypeToTopicTimer < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_timers, :type, :string, null: false, default: "TopicTimer"
    remove_index :topic_timers, name: :idx_topic_id_public_type_deleted_at
    add_index :topic_timers,
              :topic_id,
              unique: true,
              name: :idx_topic_id_public_type_deleted_at,
              where: "public_type = true AND deleted_at IS NULL AND type = 'TopicTimer'"
  end
end
