# frozen_string_literal: true
class AddEngagementScoreToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_event_scores, :engagement_score, :smallint, null: false, default: 0
  end
end
