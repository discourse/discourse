# frozen_string_literal: true

class CreateBrowserPageviewEntryUrlRollups < ActiveRecord::Migration[8.0]
  def change
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
  end
end
