# frozen_string_literal: true

class DropRedundantBrowserPageviewIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :browser_pageview_events,
                 name: "idx_bpe_session_created_at",
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :browser_pageview_events,
                 name: "idx_bpe_beacon_created_at_id",
                 algorithm: :concurrently,
                 if_exists: true
  end

  def down
    add_index :browser_pageview_events,
              %i[session_id created_at],
              name: "idx_bpe_session_created_at",
              algorithm: :concurrently
    add_index :browser_pageview_events,
              %i[created_at id],
              name: "idx_bpe_beacon_created_at_id",
              order: {
                created_at: :desc,
                id: :desc,
              },
              where: "source = 2",
              algorithm: :concurrently
  end
end
