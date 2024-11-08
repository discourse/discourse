# frozen_string_literal: true

class DropDurationColumnFromTopicTimers < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS = { topic_timers: %i[duration] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    add_column :topic_timers, :duration, :string
  end
end
