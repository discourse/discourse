# frozen_string_literal: true
class DropTopicTimerTopicId < ActiveRecord::Migration[8.0]
  def change
    change_column_null :topic_timers, :timerable_id, false
    remove_column :topic_timers, :topic_id
  end
end
