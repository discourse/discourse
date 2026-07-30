# frozen_string_literal: true
class AddDatacenterAsnScoreToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:browser_pageview_event_scores, :datacenter_asn_score)

    add_column :browser_pageview_event_scores,
               :datacenter_asn_score,
               :smallint,
               null: false,
               default: 0
  end
end
