# frozen_string_literal: true

class CreateKanbanBoardHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_kanban_board_histories do |t|
      t.bigint :acting_user_id, null: false
      t.integer :action, null: false
      t.bigint :board_id, null: false
      t.bigint :column_id
      t.jsonb :details
      t.timestamps
    end

    add_index :discourse_kanban_board_histories, :acting_user_id
    add_index :discourse_kanban_board_histories, :board_id
    add_index :discourse_kanban_board_histories, :column_id
  end
end
