# frozen_string_literal: true

class DropShowActivityIndicatorsFromBoards < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_kanban_boards: %i[show_activity_indicators] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
