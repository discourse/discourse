# frozen_string_literal: true

class AddColorToKanbanColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_kanban_columns, :color, :string
  end
end
