# frozen_string_literal: true

class AddUrlColumnToEvent < ActiveRecord::Migration[6.0]
  def up
    add_column :discourse_post_event_events, :url, :string, limit: 1000
  end

  def down
    remove_column :discourse_post_event_events, :url
  end
end
