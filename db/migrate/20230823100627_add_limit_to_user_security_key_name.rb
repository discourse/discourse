# frozen_string_literal: true

class AddLimitToUserSecurityKeyName < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      UPDATE user_security_keys
      SET name = LEFT(name, 300)
      WHERE name IS NOT NULL AND LENGTH(name) > 300
    SQL
    change_column :user_security_keys, :name, :string, limit: 300
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
