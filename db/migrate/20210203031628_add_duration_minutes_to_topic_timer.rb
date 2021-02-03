# frozen_string_literal: true

class AddDurationMinutesToTopicTimer < ActiveRecord::Migration[6.0]
  def up
    add_column :topic_timers, :duration_minutes, :integer
    DB.exec("UPDATE topic_timers SET duration_minutes = duration WHERE duration_minutes != duration")
  end

  def down
    remove_column :topic_timers, :duration_minutes
  end
end
