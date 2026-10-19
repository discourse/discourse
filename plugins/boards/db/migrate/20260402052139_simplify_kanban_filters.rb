# frozen_string_literal: true

class SimplifyKanbanFilters < ActiveRecord::Migration[8.0]
  def up
    add_column :discourse_kanban_boards,
               :category_ids,
               :integer,
               array: true,
               null: false,
               default: []
    add_column :discourse_kanban_boards, :tag_ids, :integer, array: true, null: false, default: []
    add_column :discourse_kanban_columns, :tag_id, :integer, null: true

    # Best-effort data migration: parse base_filter_query for simple category:/tags: patterns
    execute <<~SQL
      UPDATE discourse_kanban_boards
      SET category_ids = COALESCE((
        SELECT array_agg(c.id)
        FROM categories c
        JOIN LATERAL regexp_matches(base_filter_query, 'category:([^\s]+)', 'g') AS m(captures) ON TRUE
        WHERE c.slug = m.captures[1]
      ), '{}'),
      tag_ids = COALESCE((
        SELECT array_agg(t.id)
        FROM tags t
        JOIN LATERAL regexp_matches(base_filter_query, 'tags:([^\s]+)', 'g') AS m(captures) ON TRUE
        WHERE t.name = m.captures[1]
      ), '{}')
      WHERE base_filter_query IS NOT NULL AND base_filter_query != ''
    SQL

    # Migrate column move_to_tag → tag_id
    execute <<~SQL
      UPDATE discourse_kanban_columns
      SET tag_id = t.id
      FROM tags t
      WHERE discourse_kanban_columns.move_to_tag IS NOT NULL
        AND discourse_kanban_columns.move_to_tag != ''
        AND t.name = discourse_kanban_columns.move_to_tag
    SQL
  end

  def down
    remove_column :discourse_kanban_boards, :category_ids
    remove_column :discourse_kanban_boards, :tag_ids
    remove_column :discourse_kanban_columns, :tag_id
  end
end
