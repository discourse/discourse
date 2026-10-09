# frozen_string_literal: true

class DropLabelsFromKanbanCards < ActiveRecord::Migration[8.0]
  def up
    Migration::ColumnDropper.execute_drop(:discourse_kanban_cards, %i[labels])
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
