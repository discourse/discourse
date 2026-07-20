# frozen_string_literal: true

class AddBrowserFamilyToBrowserPageviewEvents < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  INDEX_NAME = "idx_bpe_source_browser_created_at_id"

  def up
    unless column_exists?(:browser_pageview_events, :browser_family)
      add_column :browser_pageview_events, :browser_family, :string, limit: 20
    end
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[source browser_family created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    remove_column :browser_pageview_events, :browser_family, if_exists: true
  end
end
