# frozen_string_literal: true

class AddDescriptionToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_post_event_events, :description, :string, limit: 1000
  end
end
