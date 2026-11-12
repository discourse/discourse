# frozen_string_literal: true
class CreateBrowserPageviewSessionEngagementDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_session_engagement_daily_rollups do |t|
      t.date :date, null: false
      t.boolean :logged_in, null: false
      t.bigint :sessions, null: false
      t.bigint :bounced, null: false
      t.bigint :engaged_seconds_total, null: false
    end

    add_index :browser_pageview_session_engagement_daily_rollups,
              %i[date logged_in],
              unique: true,
              name: "idx_bpse_rollups_date_logged_in_unique"
  end
end
