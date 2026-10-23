# frozen_string_literal: true

class AddBrowserToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :browser, :smallint
  end
end
