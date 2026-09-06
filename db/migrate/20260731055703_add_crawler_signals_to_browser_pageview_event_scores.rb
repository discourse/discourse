# frozen_string_literal: true

class AddCrawlerSignalsToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_event_scores,
               :datacenter_asn_score,
               :smallint,
               null: false,
               default: 0
    add_column :browser_pageview_event_scores,
               :single_request_no_referrer_score,
               :smallint,
               null: false,
               default: 0
    add_column :browser_pageview_event_scores,
               :stale_browser_score,
               :smallint,
               null: false,
               default: 0
  end
end
