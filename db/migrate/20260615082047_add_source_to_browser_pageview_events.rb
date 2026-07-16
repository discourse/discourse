# frozen_string_literal: true

class AddSourceToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :source, :integer, limit: 2, default: 1, null: false
  end
end
