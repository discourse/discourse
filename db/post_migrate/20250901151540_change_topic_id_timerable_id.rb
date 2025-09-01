# frozen_string_literal: true
class ChangeTopicIdTimerableId < ActiveRecord::Migration[8.0]
  def change
    rename_column :topic_timers, :topic_id, :timerable_id
  end
end
