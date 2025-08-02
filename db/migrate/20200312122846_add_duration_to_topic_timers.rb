# frozen_string_literal: true

class AddDurationToTopicTimers < ActiveRecord::Migration[6.0]
  def change
    add_column :topic_timers, :duration, :integer, null: true
  end
end
