# frozen_string_literal: true
class MarkTimerableIdNonNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :topic_timers, :timerable_id, false
  end
end
