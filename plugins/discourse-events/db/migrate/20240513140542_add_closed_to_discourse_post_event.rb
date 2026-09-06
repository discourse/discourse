# frozen_string_literal: true

class AddClosedToDiscoursePostEvent < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_post_event_events, :closed, :boolean, default: false, null: false
  end
end
