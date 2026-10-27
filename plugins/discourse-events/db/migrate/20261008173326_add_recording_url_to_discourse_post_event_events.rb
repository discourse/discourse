# frozen_string_literal: true

class AddRecordingUrlToDiscoursePostEventEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_post_event_events, :recording_url, :string, limit: 1000
  end
end
