# frozen_string_literal: true

class ChangeKanbanCardPositionToBigint < ActiveRecord::Migration[7.2]
  def up
    change_column :discourse_kanban_cards, :position, :bigint, null: false, default: 0
  end

  def down
    change_column :discourse_kanban_cards, :position, :integer, null: false, default: 0
  end
end
