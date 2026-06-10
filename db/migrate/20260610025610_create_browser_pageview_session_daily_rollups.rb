# frozen_string_literal: true

class CreateBrowserPageviewSessionDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_session_daily_rollups do |t|
      t.date :date, null: false
      t.boolean :logged_in, null: false
      t.bigint :sessions_count, null: false
      t.bigint :bounced_count, null: false
      t.bigint :total_duration_seconds, null: false
    end

    add_index :browser_pageview_session_daily_rollups,
              %i[date logged_in],
              unique: true,
              name: "idx_bpsd_rollups_date_logged_in_unique"
  end
end
