# frozen_string_literal: true
class AddNormalizedUrlToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :normalized_url, :string, limit: 2000
  end
end
