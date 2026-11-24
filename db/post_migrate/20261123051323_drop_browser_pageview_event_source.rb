# frozen_string_literal: true

class DropBrowserPageviewEventSource < ActiveRecord::Migration[8.1]
  DROPPED_COLUMNS = { browser_pageview_events: %i[source] }

  def up
    # Workers from older releases still write piggyback rows until the deploy
    # finishes, so the trigger that discards them goes with the column.
    execute <<~SQL
      DROP TRIGGER IF EXISTS skip_piggyback_browser_pageview_events ON browser_pageview_events;
      DROP FUNCTION IF EXISTS discourse_functions.skip_piggyback_browser_pageview_events();
    SQL

    # Dropping the column also drops idx_bpe_created_at_session_id, which
    # idx_bpe_created_at_session replaces.
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
