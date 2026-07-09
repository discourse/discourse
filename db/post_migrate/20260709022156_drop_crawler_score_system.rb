# frozen_string_literal: true
class DropCrawlerScoreSystem < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { browser_pageview_events: %i[score asn] }

  def up
    drop_table :browser_pageview_event_scores, if_exists: true

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }

    remove_index :browser_pageview_events, name: "idx_bpe_session_created_at", if_exists: true
    remove_index :browser_pageview_events, name: "idx_bpe_ip_ua_created_at", if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
