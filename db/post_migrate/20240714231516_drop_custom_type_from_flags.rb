# frozen_string_literal: true

class DropCustomTypeFromFlags < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { flags: %i[custom_type] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
