# frozen_string_literal: true
class DropOldCategoryTimerFields < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { categories: %i[auto_close_hours auto_close_based_on_last_post] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
