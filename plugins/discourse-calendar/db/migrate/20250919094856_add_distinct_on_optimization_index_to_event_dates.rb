# frozen_string_literal: true

class AddDistinctOnOptimizationIndexToEventDates < ActiveRecord::Migration[8.0]
  def change
    add_index :discourse_calendar_post_event_dates,
              %i[event_id finished_at starts_at],
              name: "idx_event_dates_distinct_on_optimization",
              order: {
                finished_at: :desc,
                starts_at: :desc,
              }
  end
end
