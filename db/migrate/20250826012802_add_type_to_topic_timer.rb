# frozen_string_literal: true
class AddTypeToTopicTimer < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_timers, :type, :string, null: false, default: "TopicTimer"
  end
end
