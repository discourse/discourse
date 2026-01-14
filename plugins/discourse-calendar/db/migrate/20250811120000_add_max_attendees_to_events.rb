# frozen_string_literal: true

class AddMaxAttendeesToEvents < ActiveRecord::Migration[7.0]
  def up
    add_column :discourse_post_event_events, :max_attendees, :integer
  end

  def down
    remove_column :discourse_post_event_events, :max_attendees
  end
end
