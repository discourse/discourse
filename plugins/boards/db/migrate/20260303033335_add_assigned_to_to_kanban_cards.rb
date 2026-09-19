# frozen_string_literal: true

class AddAssignedToToKanbanCards < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_kanban_cards, :assigned_to_id, :bigint, null: true
    add_column :discourse_kanban_cards, :assigned_to_type, :string, null: true

    add_index :discourse_kanban_cards,
              %i[assigned_to_type assigned_to_id],
              name: "idx_kanban_cards_assigned_to"
  end
end
