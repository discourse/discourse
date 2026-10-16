# frozen_string_literal: true

class DropUnusedBrowserPageviewVersionIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :browser_pageview_events,
                 name: "idx_bpe_normalized_url_version",
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :browser_pageview_events,
                 name: "idx_bpe_normalized_referrer_version",
                 algorithm: :concurrently,
                 if_exists: true
  end

  def down
    add_index :browser_pageview_events,
              :normalized_url_version,
              name: "idx_bpe_normalized_url_version",
              algorithm: :concurrently
    add_index :browser_pageview_events,
              :normalized_referrer_version,
              name: "idx_bpe_normalized_referrer_version",
              where: "referrer IS NOT NULL",
              algorithm: :concurrently
  end
end
