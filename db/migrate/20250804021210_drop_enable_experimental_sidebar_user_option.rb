# frozen_string_literal: true
class DropEnableExperimentalSidebarUserOption < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { user_options: %i[enable_experimental_sidebar] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
