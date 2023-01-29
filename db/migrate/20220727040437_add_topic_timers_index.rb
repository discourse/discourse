# frozen_string_literal: true

class AddTopicTimersIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :topic_timers, [:topic_id], where: "deleted_at IS NULL"
  end
end
