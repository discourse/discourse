# frozen_string_literal: true

class ReplaceBrowserBackfillIndexOnBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_browser_backfill"

  def up
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[created_at id],
              name: INDEX_NAME,
              order: {
                created_at: :desc,
                id: :desc,
              },
              where: "browser IS NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
