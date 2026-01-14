# frozen_string_literal: true
class AddUniqueConstraintToAiTools < ActiveRecord::Migration[7.1]
  def up
    # We need to remove duplicates before adding the unique constraint
    execute <<~SQL
      WITH duplicates AS (
        SELECT name, COUNT(*) as count, MIN(id) as keeper_id
        FROM ai_tools
        GROUP BY name
        HAVING COUNT(*) > 1
      )
      UPDATE ai_tools AS p
      SET name = CONCAT(p.name, p.id)
      FROM duplicates d
      WHERE p.name = d.name
      AND p.id != d.keeper_id;
    SQL

    add_index :ai_personas, :name, unique: true, if_not_exists: true
  end

  def down
    remove_index :ai_personas, :name, if_exists: true
  end
end
