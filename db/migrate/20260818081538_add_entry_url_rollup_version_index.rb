# frozen_string_literal: true

class AddEntryUrlRollupVersionIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :browser_pageview_events,
                 name: "idx_bpe_entry_url_rollup_version",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[entry_url_rollup_version created_at],
              name: "idx_bpe_entry_url_rollup_version",
              algorithm: :concurrently
  end
end
