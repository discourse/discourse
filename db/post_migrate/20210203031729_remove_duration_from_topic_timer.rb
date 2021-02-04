# frozen_string_literal: true

class RemoveDurationFromTopicTimer < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    topic_timers: %i{duration}
  }

  def up
    # 7 is delete_replies type, this duration is measured in days, the other
    # duration is measured in hours
    DB.exec("UPDATE topic_timers SET duration_minutes = (duration * 60 * 24) WHERE duration_minutes != duration AND status_type = 7 AND duration IS NOT NULL")
    DB.exec("UPDATE topic_timers SET duration_minutes = (duration * 60) WHERE duration_minutes != duration AND status_type != 7 AND duration IS NOT NULL")

    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
