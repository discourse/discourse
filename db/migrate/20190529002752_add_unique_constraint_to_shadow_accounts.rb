# frozen_string_literal: true

class AddUniqueConstraintToShadowAccounts < ActiveRecord::Migration[5.2]

  def up
    create_table :anonymous_users do |t|
      t.integer :user_id, null: false
      t.integer :master_user_id, null: false
      t.boolean :active, null: false
      t.timestamps

      t.index [:user_id], unique: true
      t.index [:master_user_id], unique: true, where: 'active'
    end

    rows = DB.exec <<~SQL
      DELETE FROM user_custom_fields
      WHERE name = 'shadow_id' AND value in (
        SELECT value
        FROM user_custom_fields
        WHERE name = 'shadow_id'
        GROUP BY value
        HAVING COUNT(*) > 1
      )
    SQL

    if rows > 0
      STDERR.puts "Removed #{rows} duplicate shadow users"
    end

    rows = DB.exec <<~SQL
      INSERT INTO anonymous_users(user_id, master_user_id, created_at, updated_at, active)
      SELECT value::int, user_id, created_at, updated_at, 't'
      FROM user_custom_fields
      WHERE name = 'shadow_id'
    SQL

    rows += DB.exec <<~SQL
      INSERT INTO anonymous_users(user_id, master_user_id, created_at, updated_at, active)
      SELECT f.user_id, value::int, f.created_at, f.updated_at, 'f'
      FROM user_custom_fields f
      LEFT JOIN anonymous_users a on a.user_id = f.user_id
      WHERE name = 'master_id' AND a.user_id IS NULL
    SQL

    if rows > 0
      STDERR.puts "Migrated #{rows} anon users to new structure"
    end

    DB.exec <<~SQL
      DELETE FROM user_custom_fields
      WHERE name in ('shadow_id', 'master_id')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
