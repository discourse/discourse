# frozen_string_literal: true

class AddBrowserPageviewEventScoresAndAsn < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :asn, :integer, null: true
    add_column :browser_pageview_events, :score, :integer, null: true

    add_index :browser_pageview_events,
              %i[session_id created_at],
              name: "idx_bpe_session_created_at"

    add_index :browser_pageview_events,
              %i[ip_address user_agent created_at],
              name: "idx_bpe_ip_ua_created_at"
  end
end
