# frozen_string_literal: true

class AddBrowserPageviewEventScoresAndAsn < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :asn, :integer, null: true
    add_column :browser_pageview_events, :score, :integer, null: true

    add_index :browser_pageview_events,
              %i[session_id created_at],
              where: "user_id IS NULL",
              name: "idx_bpe_anon_session"

    add_index :browser_pageview_events,
              %i[ip_address user_agent created_at],
              where: "user_id IS NULL",
              name: "idx_bpe_anon_ip_ua"
  end
end
