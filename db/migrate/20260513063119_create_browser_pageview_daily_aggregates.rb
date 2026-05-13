# frozen_string_literal: true

class CreateBrowserPageviewDailyAggregates < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_daily_aggregates, id: false, if_not_exists: true do |t|
      t.date :date, null: false
      t.string :country_code, limit: 2
      t.string :source_name, limit: 100, null: false
      t.boolean :is_logged_in, null: false
      t.integer :count, null: false
    end

    add_index :browser_pageview_daily_aggregates,
              %i[date country_code source_name is_logged_in],
              unique: true,
              name: "browser_pageview_daily_aggregates_with_country_idx",
              where: "country_code IS NOT NULL",
              if_not_exists: true

    add_index :browser_pageview_daily_aggregates,
              %i[date source_name is_logged_in],
              unique: true,
              name: "browser_pageview_daily_aggregates_without_country_idx",
              where: "country_code IS NULL",
              if_not_exists: true
  end
end
