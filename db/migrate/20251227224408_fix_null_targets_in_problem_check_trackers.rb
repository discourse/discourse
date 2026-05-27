# frozen_string_literal: true

class FixNullTargetsInProblemCheckTrackers < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM problem_check_trackers WHERE target IS NULL"
    change_column_null :problem_check_trackers, :target, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
