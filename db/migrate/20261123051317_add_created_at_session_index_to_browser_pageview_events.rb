# frozen_string_literal: true

class AddCreatedAtSessionIndexToBrowserPageviewEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_created_at_session"

  def up
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[created_at session_id],
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
