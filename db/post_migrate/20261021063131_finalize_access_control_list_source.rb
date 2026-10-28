# frozen_string_literal: true
class FinalizeAccessControlListSource < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE access_control_lists
      SET source = COALESCE(owner, 'core')
      WHERE source IS NULL
    SQL

    change_column_null :access_control_lists, :source, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
