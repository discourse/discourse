# frozen_string_literal: true

class EnsureUniqueFlagNameKeys < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      UPDATE flags
      SET name_key = name_key || '_' || id
      WHERE name_key IS NOT NULL
        AND id <> (
          SELECT MIN(other.id)
          FROM flags other
          WHERE other.name_key = flags.name_key
        )
    SQL

    add_index :flags, :name_key, unique: true, if_not_exists: true
  end

  def down
    remove_index :flags, :name_key, if_exists: true
  end
end
