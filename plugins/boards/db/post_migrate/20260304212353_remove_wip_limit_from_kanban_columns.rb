# frozen_string_literal: true

class RemoveWipLimitFromKanbanColumns < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_kanban_columns: %i[wip_limit] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
