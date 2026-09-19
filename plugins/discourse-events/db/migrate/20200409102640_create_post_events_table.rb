# frozen_string_literal: true

class CreatePostEventsTable < ActiveRecord::Migration[5.2]
  def up
    unless ActiveRecord::Base.connection.table_exists?("discourse_calendar_post_events")
      create_table :discourse_calendar_post_events, id: false do |t|
        t.bigint :id, null: false, primary_key: true
        t.integer :status, default: 0, null: false
        t.integer :display_invitees, default: 0, null: false
        t.datetime :starts_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
        t.datetime :ends_at
        t.datetime :deleted_at
        t.string :raw_invitees, array: true
        t.string :name
      end
    end
  end

  def down
    drop_table :discourse_calendar_post_events
  end
end
