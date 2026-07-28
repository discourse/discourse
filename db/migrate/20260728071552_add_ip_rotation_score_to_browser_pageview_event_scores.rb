# frozen_string_literal: true
class AddIpRotationScoreToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_event_scores,
               :ip_rotation_score,
               :smallint,
               null: false,
               default: 0
  end
end
