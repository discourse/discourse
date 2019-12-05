# frozen_string_literal: true

class AddUniqueIndexToDevelopers < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      DELETE FROM developers d1
      USING (
        SELECT MAX(id) as id, user_id
        FROM developers
        GROUP BY user_id
        HAVING COUNT(*) > 1
      ) d2
      WHERE
        d1.user_id = d2.user_id AND
        d1.id <> d2.id
    SQL

    add_index :developers, %i(user_id), unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
