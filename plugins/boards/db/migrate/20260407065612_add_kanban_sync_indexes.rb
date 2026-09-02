# frozen_string_literal: true

class AddKanbanSyncIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :discourse_kanban_boards,
              :category_ids,
              using: :gin,
              name: "idx_kanban_boards_category_ids"
    add_index :discourse_kanban_boards, :tag_ids, using: :gin, name: "idx_kanban_boards_tag_ids"
    add_index :discourse_kanban_columns, :tag_id, name: "idx_kanban_columns_tag_id"
  end
end
