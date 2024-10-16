# frozen_string_literal: true

class DropBadgeImageColumn < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { badges: %i[image] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
