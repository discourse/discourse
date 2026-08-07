# frozen_string_literal: true

class AddShowLocalTime < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_post_event_events, :show_local_time, :boolean, default: false, null: false
  end
end
