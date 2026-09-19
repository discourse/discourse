# frozen_string_literal: true

class AddNormalizedUrlVersionIndexToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_normalized_url_version"

  def up
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              :normalized_url_version,
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
