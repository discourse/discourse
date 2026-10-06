# frozen_string_literal: true

class AddTagIdsToKanbanCards < ActiveRecord::Migration[8.0]
  def up
    add_column :discourse_kanban_cards, :tag_ids, :integer, array: true, null: false, default: []

    execute <<~SQL
      WITH normalized_labels AS (
        SELECT DISTINCT ON (lower(trim(label)))
          trim(label) AS name,
          lower(trim(label)) AS lower_name
        FROM discourse_kanban_cards
        CROSS JOIN LATERAL unnest(labels) AS labels(label)
        WHERE trim(COALESCE(label, '')) <> ''
        ORDER BY lower(trim(label)), trim(label)
      )
      INSERT INTO tags (name, slug, created_at, updated_at)
      SELECT normalized_labels.name, '', NOW(), NOW()
      FROM normalized_labels
      LEFT JOIN tags ON lower(tags.name) = normalized_labels.lower_name
      WHERE tags.id IS NULL
    SQL

    execute <<~SQL
      WITH normalized_labels AS (
        SELECT
          discourse_kanban_cards.id AS card_id,
          lower(trim(label)) AS lower_name,
          ord,
          ROW_NUMBER() OVER (
            PARTITION BY discourse_kanban_cards.id, lower(trim(label))
            ORDER BY ord
          ) AS row_number
        FROM discourse_kanban_cards
        CROSS JOIN LATERAL unnest(labels) WITH ORDINALITY AS labels(label, ord)
        WHERE trim(COALESCE(label, '')) <> ''
      ),
      resolved_tag_ids AS (
        SELECT
          normalized_labels.card_id,
          array_agg(tags.id ORDER BY normalized_labels.ord) AS tag_ids
        FROM normalized_labels
        INNER JOIN tags ON lower(tags.name) = normalized_labels.lower_name
        WHERE normalized_labels.row_number = 1
        GROUP BY normalized_labels.card_id
      )
      UPDATE discourse_kanban_cards
      SET tag_ids = COALESCE(resolved_tag_ids.tag_ids, '{}')
      FROM resolved_tag_ids
      WHERE discourse_kanban_cards.id = resolved_tag_ids.card_id
    SQL
  end

  def down
    remove_column :discourse_kanban_cards, :tag_ids
  end
end
