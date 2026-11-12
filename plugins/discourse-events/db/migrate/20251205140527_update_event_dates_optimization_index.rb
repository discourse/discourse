# frozen_string_literal: true

class UpdateEventDatesOptimizationIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :discourse_calendar_post_event_dates,
                 name: "index_discourse_calendar_post_event_dates_on_event_id_and_dates",
                 if_exists: true,
                 algorithm: :concurrently

    # Covering index for the DISTINCT ON query which orders by:
    # event_id, finished_at IS NOT NULL, CASE WHEN finished_at IS NULL THEN starts_at ELSE updated_at END DESC, id DESC
    add_index :discourse_calendar_post_event_dates,
              %i[event_id finished_at starts_at updated_at id],
              name: "index_discourse_calendar_post_event_dates_on_event_id_and_dates",
              order: {
                starts_at: :desc,
                updated_at: :desc,
                id: :desc,
              },
              algorithm: :concurrently
  end

  def down
    remove_index :discourse_calendar_post_event_dates,
                 name: "index_discourse_calendar_post_event_dates_on_event_id_and_dates",
                 if_exists: true,
                 algorithm: :concurrently

    add_index :discourse_calendar_post_event_dates,
              %i[event_id finished_at starts_at],
              name: "index_discourse_calendar_post_event_dates_on_event_id_and_dates",
              order: {
                finished_at: :desc,
                starts_at: :desc,
              },
              algorithm: :concurrently
  end
end
