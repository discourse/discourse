# frozen_string_literal: true
class DropTopicTimerTopicId < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { topic_timers: %i[topic_id] }

  def up
    change_column_null :topic_timers, :timerable_id, false
    Migration::ColumnDropper.drop_readonly(:topic_timers, :topic_id)

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
