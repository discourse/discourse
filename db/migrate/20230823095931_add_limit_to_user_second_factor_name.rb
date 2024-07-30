# frozen_string_literal: true

class AddLimitToUserSecondFactorName < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      UPDATE user_second_factors
      SET name = LEFT(name, 300)
      WHERE name IS NOT NULL AND LENGTH(name) > 300
    SQL
    change_column :user_second_factors, :name, :string, limit: 300
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
