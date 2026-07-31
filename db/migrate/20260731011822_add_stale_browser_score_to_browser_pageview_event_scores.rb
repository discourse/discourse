# frozen_string_literal: true

class AddStaleBrowserScoreToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:browser_pageview_event_scores, :stale_browser_score)

    add_column :browser_pageview_event_scores,
               :stale_browser_score,
               :smallint,
               null: false,
               default: 0
  end
end
