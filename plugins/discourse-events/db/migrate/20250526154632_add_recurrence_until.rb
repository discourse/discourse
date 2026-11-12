# frozen_string_literal: true
#
class AddRecurrenceUntil < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_post_event_events, :recurrence_until, :datetime
  end
end
