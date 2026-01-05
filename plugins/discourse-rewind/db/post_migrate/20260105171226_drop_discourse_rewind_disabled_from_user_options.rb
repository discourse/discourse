# frozen_string_literal: true

class DropDiscourseRewindDisabledFromUserOptions < ActiveRecord::Migration[7.2]
  DROPPED_COLUMNS = { user_options: %i[discourse_rewind_disabled] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
