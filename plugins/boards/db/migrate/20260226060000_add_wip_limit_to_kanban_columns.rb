# frozen_string_literal: true

class AddWipLimitToKanbanColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_kanban_columns, :wip_limit, :integer, null: true
  end
end
