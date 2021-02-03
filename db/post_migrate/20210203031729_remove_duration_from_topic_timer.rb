# frozen_string_literal: true

class RemoveDurationFromTopicTimer < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    topic_timers: %i{duration}
  }

  def up
    DB.exec("UPDATE topic_timers SET duration_minutes = duration WHERE duration_minutes != duration")
    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
