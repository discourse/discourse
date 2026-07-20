# frozen_string_literal: true

class CreateBrowserPageviewUrlDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :browser_pageview_url_daily_rollups do |t|
      t.date :date, null: false
      t.string :normalized_url, limit: 2000
      t.bigint :count, null: false
      t.bigint :logged_in_count, null: false
    end

    add_index :browser_pageview_url_daily_rollups,
              %i[date normalized_url],
              unique: true,
              nulls_not_distinct: true,
              name: "idx_bpud_rollups_date_url_unique"
  end
end
