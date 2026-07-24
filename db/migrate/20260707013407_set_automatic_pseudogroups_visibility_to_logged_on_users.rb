# frozen_string_literal: true

class SetAutomaticPseudogroupsVisibilityToLoggedOnUsers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE groups
      SET visibility_level = 1
      WHERE id IN (0, 4, 5)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
