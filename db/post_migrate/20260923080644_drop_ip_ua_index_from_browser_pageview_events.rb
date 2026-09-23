# frozen_string_literal: true

class DropIpUaIndexFromBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_ip_ua_created_at"

  def up
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end

  def down
    add_index :browser_pageview_events,
              %i[ip_address user_agent created_at],
              name: INDEX_NAME,
              algorithm: :concurrently
  end
end
