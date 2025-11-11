# frozen_string_literal: true

class DropDarkHexFromColorSchemeColor < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { color_scheme_colors: %i[dark_hex] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
