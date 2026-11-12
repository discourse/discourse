# frozen_string_literal: true

class AllowTopicInMultipleColumns < ActiveRecord::Migration[7.2]
  def up
    remove_index :discourse_kanban_cards, name: :idx_kanban_cards_unique_topic_per_board

    execute <<~SQL
      CREATE UNIQUE INDEX idx_kanban_cards_unique_topic_per_column
      ON discourse_kanban_cards (board_id, column_id, topic_id)
      WHERE topic_id IS NOT NULL AND column_id IS NOT NULL
    SQL
  end

  def down
    remove_index :discourse_kanban_cards, name: :idx_kanban_cards_unique_topic_per_column

    # De-duplicate: keep the best card per (board_id, topic_id).
    # Priority: manual_in (visible) > auto (visible) > manual_out (hidden),
    # then prefer cards with a column, then lowest id as tiebreaker.
    execute <<~SQL
      DELETE FROM discourse_kanban_cards
      WHERE topic_id IS NOT NULL
        AND id NOT IN (
          SELECT DISTINCT ON (board_id, topic_id) id
          FROM discourse_kanban_cards
          WHERE topic_id IS NOT NULL
          ORDER BY board_id, topic_id,
            CASE membership_mode
              WHEN 1 THEN 0
              WHEN 0 THEN 1
              WHEN 2 THEN 2
              ELSE 3
            END,
            (column_id IS NULL)::int,
            id
        )
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX idx_kanban_cards_unique_topic_per_board
      ON discourse_kanban_cards (board_id, topic_id)
      WHERE topic_id IS NOT NULL
    SQL
  end
end
