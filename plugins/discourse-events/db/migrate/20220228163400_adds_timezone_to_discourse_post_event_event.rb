# frozen_string_literal: true

class AddsTimezoneToDiscoursePostEventEvent < ActiveRecord::Migration[6.1]
  def change
    add_column :discourse_post_event_events, :timezone, :string
  end
end
