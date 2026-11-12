# frozen_string_literal: true

class CreateBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_event_scores do |t|
      t.bigint :event_id, null: false
      t.column :automation_ua_score, :smallint, null: false, default: 0
      t.column :known_asn_score, :smallint, null: false, default: 0
      t.column :velocity_score, :smallint, null: false, default: 0
      t.column :churn_score, :smallint, null: false, default: 0
      t.column :rapid_nav_score, :smallint, null: false, default: 0
      t.column :referrer_score, :smallint, null: false, default: 0
    end

    add_index :browser_pageview_event_scores, :event_id, unique: true
  end
end
