# frozen_string_literal: true

class SetBrowserPageviewEventSourceDefaultToBeacon < ActiveRecord::Migration[8.0]
  def change
    change_column_default :browser_pageview_events, :source, from: 1, to: 2
  end
end
