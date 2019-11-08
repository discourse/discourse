# frozen_string_literal: true

class AddUniqueIndexToDrafts < ActiveRecord::Migration[6.0]
  def up

    execute <<~SQL
      DELETE FROM drafts d1
      USING (
        SELECT MAX(id) as id, draft_key, user_id
        FROM drafts
        GROUP BY draft_key, user_id
        HAVING COUNT(*) > 1
      ) d2
      WHERE
        d1.draft_key = d2.draft_key AND
        d1.user_id = d2.user_id AND
        d1.id <> d2.id
    SQL

    remove_index :drafts, [:user_id, :draft_key]
    add_index :drafts, [:user_id, :draft_key], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
