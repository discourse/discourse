# frozen_string_literal: true

class AddIpCreatedAtIndexToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_ip_created_at"

  def up
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[ip_address created_at],
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
