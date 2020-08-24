# frozen_string_literal: true

class DisassociateReviewableUserData < ActiveRecord::Migration[6.0]
  def up
    DB.exec(
      <<~SQL
        UPDATE reviewables r
        SET target_type = NULL, target_id = NULL
        FROM reviewables r2
        LEFT JOIN users ON users.id = r2.target_id 
        WHERE r2.type = 'ReviewableUser' AND r2.target_type = 'User' AND r2.status = 2 AND users.id IS NULL AND r.id = r2.id
      SQL
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
