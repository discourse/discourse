class AddTrustLevelLocksToUsers < ActiveRecord::Migration[5.1]
  def up
    add_column :users, :group_locked_trust_level, :integer, null: true
    add_column :users, :manual_locked_trust_level, :integer, null: true

    execute <<~SQL
      UPDATE users SET manual_locked_trust_level = trust_level WHERE trust_level_locked
    SQL

    execute <<~SQL
      UPDATE users SET group_locked_trust_level = x.tl
      FROM users AS u
      INNER JOIN (
        SELECT gu.user_id, MAX(g.grant_trust_level) AS tl
        FROM group_users AS gu
        INNER JOIN groups AS g ON gu.group_id = g.id
          WHERE g.grant_trust_level IS NOT NULL
        GROUP BY gu.user_id
      ) AS x ON x.user_id = u.id
      WHERE users.id = u.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
