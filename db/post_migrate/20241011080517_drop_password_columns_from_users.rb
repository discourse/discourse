# frozen_string_literal: true
class DropPasswordColumnsFromUsers < ActiveRecord::Migration[7.1]
  DROPPED_COLUMNS = { users: %i[password_hash salt password_algorithm] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
