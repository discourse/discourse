# frozen_string_literal: true
class AddSingleRequestNoReferrerScoreToBrowserPageviewEventScores < ActiveRecord::Migration[8.0]
  def change
    return if column_exists?(:browser_pageview_event_scores, :single_request_no_referrer_score)

    add_column :browser_pageview_event_scores,
               :single_request_no_referrer_score,
               :smallint,
               null: false,
               default: 0
  end
end
