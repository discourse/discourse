# frozen_string_literal: true

class CreateBrowserPageviewEntryUrlRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_entry_url_sessions do |t|
      t.string :session_id, limit: 32, null: false
      t.bigint :first_event_id, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.string :entry_url, limit: 2000
      t.boolean :logged_in, null: false
      t.boolean :likely_crawler, default: false, null: false
      t.timestamps
    end

    add_index :browser_pageview_entry_url_sessions,
              :session_id,
              unique: true,
              name: "idx_bpeu_sessions_session_unique"
    add_index :browser_pageview_entry_url_sessions,
              :first_seen_at,
              using: :brin,
              name: "idx_bpeu_sessions_first_seen"
    add_index :browser_pageview_entry_url_sessions,
              :last_seen_at,
              using: :brin,
              name: "idx_bpeu_sessions_last_seen"
    create_table :browser_pageview_entry_url_daily_rollups do |t|
      t.date :date, null: false
      t.string :entry_url, limit: 2000, null: false
      t.bigint :count, null: false
      t.bigint :logged_in_count, null: false
      t.bigint :likely_crawler_count, default: 0, null: false
      t.bigint :likely_crawler_logged_in_count, default: 0, null: false
    end

    add_index :browser_pageview_entry_url_daily_rollups,
              %i[date entry_url],
              unique: true,
              name: "idx_bpeu_daily_rollups_date_url_unique"

    create_table :browser_pageview_entry_url_daily_rollup_dates do |t|
      t.date :date, null: false
    end

    add_index :browser_pageview_entry_url_daily_rollup_dates,
              :date,
              unique: true,
              name: "idx_bpeu_daily_rollup_dates_unique"

    create_table :browser_pageview_entry_url_dirty_dates do |t|
      t.date :date, null: false
      t.integer :bucket, null: false
      t.bigint :generation, default: 1, null: false
    end

    add_index :browser_pageview_entry_url_dirty_dates,
              %i[date bucket],
              unique: true,
              name: "idx_bpeu_dirty_dates_unique"
  end
end
