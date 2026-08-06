# frozen_string_literal: true

class AddNormalizedUrlVersionIndexToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_stale_normalized_url"

  def up
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              :id,
              name: INDEX_NAME,
              where: "normalized_url_version IS NULL OR normalized_url_version < 1",
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
