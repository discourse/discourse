# frozen_string_literal: true

class AddDurationMinutesToTopicTimer < ActiveRecord::Migration[6.0]
  def up
    add_column :topic_timers, :duration_minutes, :integer

    # 7 is delete_replies type, this duration is measured in days, the other
    # duration is measured in hours
    DB.exec(
      "UPDATE topic_timers SET duration_minutes = (duration * 60 * 24) WHERE duration_minutes != duration AND status_type = 7 AND duration IS NOT NULL",
    )
    DB.exec(
      "UPDATE topic_timers SET duration_minutes = (duration * 60) WHERE duration_minutes != duration AND status_type != 7 AND duration IS NOT NULL",
    )
  end

  def down
    remove_column :topic_timers, :duration_minutes
  end
end
