# frozen_string_literal: true

class AddLocationToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_post_event_events, :location, :string, limit: 1000
  end
end
