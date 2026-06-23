# frozen_string_literal: true

class CreateBrowserPageviewSessionEngagements < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_session_engagements do |t|
      t.string :session_id, null: false, limit: 32
      t.integer :mouse_move_events, null: false, default: 0
      t.integer :click_events, null: false, default: 0
      t.integer :key_events, null: false, default: 0
      t.integer :scroll_events, null: false, default: 0
      t.integer :touch_events, null: false, default: 0
      t.integer :back_forward_events, null: false, default: 0
      t.integer :engaged_duration_ms, null: false, default: 0
      t.integer :time_to_first_interaction_ms, null: true
      t.timestamps
    end

    add_index :browser_pageview_session_engagements, :session_id, unique: true
    add_index :browser_pageview_session_engagements, :created_at, using: :brin
  end
end
