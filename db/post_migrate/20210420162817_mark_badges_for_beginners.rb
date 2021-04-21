# frozen_string_literal: true

class MarkBadgesForBeginners < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      UPDATE badges
      SET for_beginners = true
      WHERE id IN (
        5,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        40,
        41,
        42,
        43,
        48,
        100,
        101,
        102
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
