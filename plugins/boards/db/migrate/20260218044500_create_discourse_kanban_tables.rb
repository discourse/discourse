# frozen_string_literal: true

class CreateDiscourseKanbanTables < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_kanban_boards do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :base_filter_query

      t.integer :allow_read_group_ids, array: true, null: false, default: []
      t.integer :allow_write_group_ids, array: true, null: false, default: []

      t.boolean :require_confirmation, null: false, default: true
      t.boolean :show_tags, null: false, default: false
      t.integer :card_style, null: false, default: 0
      t.boolean :show_topic_thumbnail, null: false, default: false
      t.boolean :show_activity_indicators, null: false, default: false

      t.bigint :created_by_id
      t.bigint :updated_by_id

      t.timestamps
    end

    add_index :discourse_kanban_boards, :slug, unique: true
    add_index :discourse_kanban_boards, :created_by_id

    create_table :discourse_kanban_columns do |t|
      t.references :board,
                   null: false,
                   foreign_key: {
                     to_table: :discourse_kanban_boards,
                     on_delete: :cascade,
                   },
                   index: {
                     name: "idx_kanban_columns_board_id",
                   }

      t.string :title, null: false
      t.string :icon
      t.integer :position, null: false, default: 0

      t.text :filter_query
      t.string :move_to_tag
      t.bigint :move_to_category_id
      t.string :move_to_assigned
      t.string :move_to_status

      t.timestamps
    end

    add_index :discourse_kanban_columns,
              %i[board_id position],
              name: "idx_kanban_columns_board_position"
    add_foreign_key :discourse_kanban_columns,
                    :categories,
                    column: :move_to_category_id,
                    on_delete: :nullify

    create_table :discourse_kanban_cards do |t|
      t.references :board,
                   null: false,
                   foreign_key: {
                     to_table: :discourse_kanban_boards,
                     on_delete: :cascade,
                   },
                   index: {
                     name: "idx_kanban_cards_board_id",
                   }

      t.references :column,
                   null: true,
                   foreign_key: {
                     to_table: :discourse_kanban_columns,
                     on_delete: :nullify,
                   },
                   index: {
                     name: "idx_kanban_cards_column_id",
                   }

      t.references :topic,
                   null: true,
                   foreign_key: {
                     to_table: :topics,
                     on_delete: :cascade,
                   },
                   index: {
                     name: "idx_kanban_cards_topic_id",
                   }

      t.integer :card_type, null: false, default: 0
      t.integer :membership_mode, null: false, default: 1

      t.string :title
      t.text :notes
      t.text :labels, array: true, null: false, default: []
      t.datetime :due_at

      t.integer :position, null: false, default: 0

      t.bigint :created_by_id
      t.bigint :updated_by_id

      t.timestamps
    end

    add_index :discourse_kanban_cards,
              %i[board_id column_id position],
              name: "idx_kanban_cards_board_column_position"

    execute <<~SQL
      CREATE UNIQUE INDEX idx_kanban_cards_unique_topic_per_board
      ON discourse_kanban_cards (board_id, topic_id)
      WHERE topic_id IS NOT NULL
    SQL
  end
end
