# frozen_string_literal: true
class RemoveGroupIdFromPostPolicy < ActiveRecord::Migration[6.1]
  def up
    Migration::ColumnDropper.execute_drop(:post_policies, [:group_id])
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
