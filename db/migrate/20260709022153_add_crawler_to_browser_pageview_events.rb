# frozen_string_literal: true
class AddCrawlerToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :crawler, :boolean, null: false, default: false
  end
end
