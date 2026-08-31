# frozen_string_literal: true

class DropSourceFromBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { browser_pageview_events: %i[source] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
