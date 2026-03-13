# frozen_string_literal: true

class DropDiscourseRewindDisabledFromUserOptions < ActiveRecord::Migration[7.2]
  DROPPED_COLUMNS = { user_options: %i[discourse_rewind_disabled] }

  def up
    # Repeat the backfill in case any data was added during the deploy window
    execute <<~SQL
      UPDATE user_options
      SET discourse_rewind_enabled = NOT discourse_rewind_disabled
      WHERE discourse_rewind_enabled != (NOT discourse_rewind_disabled)
    SQL

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
