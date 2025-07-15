# frozen_string_literal: true

class AddMinimalOptionToCalendarEvent < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_post_event_events, :minimal, :boolean
  end
end
