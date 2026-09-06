# frozen_string_literal: true

class DropKanbanCardMembershipMode < ActiveRecord::Migration[8.0]
  def up
    # Delete orphaned cards with no column (manual_out markers)
    execute <<~SQL
      DELETE FROM discourse_kanban_cards WHERE column_id IS NULL
    SQL

    # Remove the membership_mode column
    remove_column :discourse_kanban_cards, :membership_mode
  end

  def down
    add_column :discourse_kanban_cards, :membership_mode, :integer, default: 1, null: false
  end
end
