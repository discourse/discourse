# frozen_string_literal: true

class DropOldKanbanFilterColumns < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = {
    discourse_kanban_boards: %i[base_filter_query],
    discourse_kanban_columns: %i[filter_query move_to_tag],
  }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
