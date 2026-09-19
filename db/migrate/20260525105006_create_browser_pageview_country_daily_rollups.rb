# frozen_string_literal: true
class CreateBrowserPageviewCountryDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_country_daily_rollups do |t|
      t.date :date, null: false
      t.string :country_code, limit: 2
      t.bigint :count, null: false
      t.bigint :logged_in_count, null: false
    end

    add_index :browser_pageview_country_daily_rollups,
              %i[date country_code],
              unique: true,
              nulls_not_distinct: true,
              name: "idx_bpcd_rollups_date_country_unique"
  end
end
