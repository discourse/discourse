# frozen_string_literal: true
class AddNormalizedReferrerVersionToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :normalized_referrer_version, :integer, limit: 2
  end
end
