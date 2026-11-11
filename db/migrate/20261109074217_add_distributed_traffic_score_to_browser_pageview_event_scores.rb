# frozen_string_literal: true

class AddDistributedTrafficScoreToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    %i[browser_pageview_event_scores browser_pageview_event_scores_backup].each do |table|
      add_column table, :distributed_traffic_score, :smallint, null: false, default: 0
    end
  end
end
