# frozen_string_literal: true

class DeleteDuplicatedHolidays < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE
        FROM calendar_events ce
      WHERE
        ce.id IN (SELECT ce2.id FROM calendar_events ce2
                  INNER JOIN users ON users.id = ce2.user_id
                  WHERE ce2.post_id IS NULL
                    AND ce2.username != users.username)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
