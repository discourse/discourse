# frozen_string_literal: true

class AddBackfillIndexesToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  URL_INDEX_NAME = "idx_bpe_url_backfill"
  REFERRER_INDEX_NAME = "idx_bpe_referrer_backfill"

  def up
    remove_index :browser_pageview_events,
                 name: URL_INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              where: "normalized_url_version IS NULL OR normalized_url_version < 1",
              name: URL_INDEX_NAME,
              algorithm: :concurrently

    remove_index :browser_pageview_events,
                 name: REFERRER_INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              where:
                "referrer IS NOT NULL AND (normalized_referrer_version IS NULL OR normalized_referrer_version < 1)",
              name: REFERRER_INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: URL_INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :browser_pageview_events,
                 name: REFERRER_INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
