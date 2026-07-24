# frozen_string_literal: true

class AddNormalizedReferrerToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :normalized_referrer, :string, limit: 2000
  end
end
