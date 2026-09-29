# frozen_string_literal: true

class DropUnusedBrowserPageviewIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    %w[
      index_browser_pageview_events_on_user_id
      index_browser_pageview_events_on_topic_id
    ].each do |name|
      remove_index :browser_pageview_events, name: name, algorithm: :concurrently, if_exists: true
    end
  end

  def down
    add_index :browser_pageview_events, :user_id, algorithm: :concurrently
    add_index :browser_pageview_events, :topic_id, algorithm: :concurrently
  end
end
