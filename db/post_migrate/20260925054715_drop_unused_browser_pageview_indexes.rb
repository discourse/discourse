# frozen_string_literal: true

class DropUnusedBrowserPageviewIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    %w[
      idx_bpe_created_at_country_code
      idx_bpe_created_at_normalized_referrer
      index_browser_pageview_events_on_user_id
      index_browser_pageview_events_on_topic_id
    ].each do |name|
      remove_index :browser_pageview_events, name: name, algorithm: :concurrently, if_exists: true
    end
  end

  def down
    add_index :browser_pageview_events,
              %i[created_at country_code],
              name: "idx_bpe_created_at_country_code",
              algorithm: :concurrently
    add_index :browser_pageview_events,
              %i[created_at normalized_referrer],
              name: "idx_bpe_created_at_normalized_referrer",
              algorithm: :concurrently
    add_index :browser_pageview_events, :user_id, algorithm: :concurrently
    add_index :browser_pageview_events, :topic_id, algorithm: :concurrently
  end
end
