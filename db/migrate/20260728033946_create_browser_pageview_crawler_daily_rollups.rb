# frozen_string_literal: true

class CreateBrowserPageviewCrawlerDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_crawler_daily_rollups do |t|
      t.date :date, null: false
      t.boolean :logged_in, null: false
      t.bigint :count, null: false
    end

    add_index :browser_pageview_crawler_daily_rollups,
              %i[date logged_in],
              unique: true,
              name: "idx_bpcrawler_rollups_date_logged_in_unique"
  end
end
