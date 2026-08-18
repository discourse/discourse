# frozen_string_literal: true

class AddAllDayToDiscoursePostEventEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_post_event_events, :all_day, :boolean, default: false, null: false
  end
end
