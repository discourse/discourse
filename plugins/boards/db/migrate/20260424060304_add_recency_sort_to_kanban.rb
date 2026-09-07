# frozen_string_literal: true

class AddRecencySortToKanban < ActiveRecord::Migration[8.0]
  def up
    add_column :discourse_kanban_columns, :default_sort, :integer, null: false, default: 0
    add_column :discourse_kanban_cards, :column_changed_at, :datetime

    execute <<~SQL
      UPDATE discourse_kanban_cards
      SET column_changed_at = COALESCE(updated_at, created_at, NOW())
      WHERE column_changed_at IS NULL
    SQL

    change_column_null :discourse_kanban_cards, :column_changed_at, false
  end

  def down
    remove_column :discourse_kanban_cards, :column_changed_at
    remove_column :discourse_kanban_columns, :default_sort
  end
end
