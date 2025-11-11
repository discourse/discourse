# frozen_string_literal: true

class AddRecurrenceToEvents < ActiveRecord::Migration[6.0]
  def up
    add_column :discourse_post_event_events, :recurrence, :string
  end

  def down
    remove_column :discourse_post_event_events, :recurrence
  end
end
